require File.join(File.dirname(__FILE__), "helpers")
require "sensu/spawn"

describe "Sensu::Spawn" do
  include Helpers

  it "can spawn a process" do
    async_wrapper do
      Sensu::Spawn.process("echo foo") do |output, status|
        expect(output).to eq("foo\n")
        expect(status).to eq(0)
        async_done
      end
    end
  end

  it "can spawn a process with output greater than 64KB" do |output, status|
    output_asset = "spec/assets/output_1MB"
    expected_output = IO.read(output_asset)
    async_wrapper do
      Sensu::Spawn.process("cat #{output_asset}") do |output, status|
        expect(output).to eq(expected_output)
        expect(status).to eq(0)
        async_done
      end
    end
  end


  it "can spawn a process with a non-zero exit status" do
    async_wrapper do
      Sensu::Spawn.process("echo foo && exit 1") do |output, status|
        expect(output).to eq("foo\n")
        expect(status).to eq(1)
        async_done
      end
    end
  end

  it "can spawn a process using an unknown command" do
    async_wrapper do
      Sensu::Spawn.process("unknown.command") do |output, status|
        expect(output).to include("unknown")
        expect(status).to eq(127)
        async_done
      end
    end
  end

  it "can spawn a process with a timeout" do
    async_wrapper do
      Sensu::Spawn.process("sleep 5", :timeout => 0.5) do |output, status|
        expect(output).to eq("Execution timed out")
        expect(status).to eq(2)
        async_done
      end
    end
  end

  it "can spawn a process that reads from STDIN" do
    async_wrapper do
      Sensu::Spawn.process("cat", :data => "bar") do |output, status|
        expect(output).to eq("bar")
        expect(status).to eq(0)
        async_done
      end
    end
  end

  it "can spawn many process and release resources (e.g. file handles)" do
    async_wrapper do
      1000.times do
        Sensu::Spawn.process("echo foo && exit 1")
      end
      EM::Timer.new(5) do
        ObjectSpace.each_object(IO) do |f|
          puts f.inspect
        end
        async_done
      end
    end
  end
end
