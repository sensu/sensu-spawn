gem "em-worker", "0.0.2"
gem "childprocess", "0.5.8"

require "eventmachine"
require "em/worker"
require "childprocess"
require "rbconfig"

# Attempt an upfront loading of FFI and POSIX spawn libraries. These
# libraries may fail to load on certain platforms, load errors are
# silenced, and the libraries are not used by Sensu Spawn.
begin
  require "ffi"
  require "childprocess/unix/platform/#{ChildProcess.platform_name}"
  require "childprocess/unix/lib"
  require "childprocess/unix/posix_spawn_process"
rescue LoadError; end

module Sensu
  module Spawn
    POSIX_SPAWN_PLATFORMS = [:linux, :macosx].freeze

    @@mutex = Mutex.new

    class << self
      # Setup a spawn process worker, to limit the number of
      # concurrent child processes allowed at one time. This method
      # creates the spawn process worker instance variable:
      # `@process_worker`.
      #
      # @param [Hash] options to create a process worker with.
      # @option options [Integer] :limit max number of child processes
      #   at a time.
      def setup(options={})
        limit = options[:limit] || 12
        @process_worker ||= EM::Worker.new(:concurrency => limit)
      end

      # Spawn a child process. The EventMachine reactor (loop) must be
      # running for this method to work.
      #
      # @param [String] command to run.
      # @param [Hash] options to create a child process with.
      # @option options [String] :data to write to STDIN.
      # @option options [Integer] :timeout in seconds.
      # @param [Proc] callback called when the child process exits,
      #   its output and exit status are passed as parameters.
      def process(command, options={}, &callback)
        create = Proc.new do
          child_process(command, options)
        end
        setup(options) unless @process_worker
        @process_worker.enqueue(create, callback)
      end

      # Determine if POSIX Spawn is used to create child processes on
      # the current platform. ChildProcess supports POSIX Spawn for
      # several platforms (OSs & architectures), however, Sensu only
      # enables the use of POSIX Spawn on a select few.
      def posix_spawn?
        @posix_spawn ||= POSIX_SPAWN_PLATFORMS.include?(ChildProcess.os)
      end

      # Build a child process attached to a pipe, in order to capture
      # its output (STDERR, STDOUT). The child process will be a
      # platform dependent shell, that is responsible for executing
      # the provided command.
      #
      # @param [String] command to run.
      # @return [Array] child object, pipe reader, pipe writer.
      def build_child_process(command)
        reader, writer = IO.pipe
        shell = case RUBY_PLATFORM
        when /(ms|cyg|bcc)win|mingw|win32/
          ["cmd", "/c"]
        else
          ["sh", "-c"]
        end
        ChildProcess.posix_spawn = posix_spawn?
        shell_command = shell + [command]
        child = ChildProcess.build(*shell_command)
        child.io.stdout = child.io.stderr = writer
        child.leader = true
        [child, reader, writer]
      end

      # Read a stream/file until end of file (EOF).
      #
      # @param [Object] reader to read contents of until EOF.
      # @return [String] the stream/file contents.
      def read_until_eof(reader)
        output = ""
        begin
          loop { output << reader.readpartial(8192) }
        rescue EOFError
        end
        reader.close
        output
      end

      # Create a child process, return its output (STDERR & STDOUT),
      # and exit status. The child process will have its own process
      # group, may accept data via STDIN, and have a timeout.
      # ChildProcess Unix POSIX spawn (`start()`) is not thread safe,
      # so a mutex is used to allow safe execution on Ruby runtimes
      # with real threads (JRuby).
      #
      # The child process timeout functionality needs to be re-worked,
      # as it currenty allows for a deadlock, when the child output is
      # greater than the OS max buffer size.
      #
      # @param [String] command to run.
      # @param [Hash] options to create a child process with.
      # @option options [String] :data to write to STDIN.
      # @option options [Integer] :timeout in seconds.
      # @return [Array] child process output and exit status.
      def child_process(command, options={})
        child, reader, writer = build_child_process(command)
        child.duplex = true if options[:data]
        @@mutex.synchronize do
          child.start
        end
        writer.close
        if options[:data]
          child.io.stdin.write(options[:data])
          child.io.stdin.close
        end
        if options[:timeout]
          child.poll_for_exit(options[:timeout])
          output = read_until_eof(reader)
        else
          output = read_until_eof(reader)
          child.wait
        end
        [output, child.exit_code]
      rescue ChildProcess::TimeoutError
        child.stop rescue nil
        ["Execution timed out", 2]
      rescue => error
        child.stop rescue nil
        ["Unexpected error: #{error}", 3]
      end
    end
  end
end
