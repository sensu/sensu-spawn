gem "sensu-em"
gem "em-worker", "0.0.2"

require "eventmachine"
require "em/worker"
require "childprocess"

module Sensu
  module Spawn
    class << self
      # Spawn a child process. A maximum of 12 processes will be
      # spawned at a time. The EventMachine reactor (loop) must be
      # running for this method to work.
      #
      # @param [String] command to run.
      # @param [Hash] options to create a child process with.
      # @option options [String] :data to write to STDIN.
      # @option options [Integer] :timeout in seconds.
      def process(*args, &callback)
        create = Proc.new do
          child_process(*args)
        end
        @process_worker ||= EM::Worker.new
        @process_worker.enqueue(create, callback)
      end

      private

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
          shell = ["cmd", "/c"]
        else
          shell = ["sh", "-c"]
        end
        ChildProcess.posix_spawn = true
        child = ChildProcess.build(*shell, command)
        child.io.stdout = child.io.stderr = writer
        child.leader = true
        [child, reader, writer]
      end

      # Read a stream/file until end of file (EOF).
      #
      # @param reader [Object] to read contents of until EOF.
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
      #
      # @param [String] command to run.
      # @param [Hash] options to create a child process with.
      # @option options [String] :data to write to STDIN.
      # @option options [Integer] :timeout in seconds.
      # @return [Array] child process output and exit status.
      def child_process(command, options={})
        child, reader, writer = build_child_process(command)
        child.duplex = true if options[:data]
        child.start
        if options[:data]
          child.io.stdin.write(options[:data])
          child.io.stdin.close
        end
        if options[:timeout]
          child.poll_for_exit(options[:timeout])
        else
          child.wait
        end
        writer.close
        [read_until_eof(reader), child.exit_code]
      rescue ChildProcess::TimeoutError
        child.stop
        ["Execution timed out", 2]
      rescue => error
        child.stop
        ["Unexpected error: #{error}", 3]
      end
    end
  end
end
