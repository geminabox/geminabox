require_relative '../../test_helper'

module Geminabox
  class ServerTest < Minitest::Test
    class FileOpenNoYield
      attr_reader :name, :mode, :block, :mock_file
      def initialize(dummy) ; end

      def open(name, mode, &block)
        @name, @mode, @block = name, mode, block
      end
    end

    class FileOpenYields
      attr_reader :mock_file

      def initialize(flock_return)
        @mock_file = Object.new
        mock_file.define_singleton_method(:flock) {|operator| flock_return }
      end

      def open(name, mode)
        mock_file.define_singleton_method(:path) { name }
        yield mock_file
      end
    end

    module PrepServer
      attr_reader :server, :fake_file_class, :mock_file

      def prep_server(klass, flock_return = nil)
        @server = Geminabox::Server.new.instance_variable_get(:@instance)
        # ivar for the tests.  Local variable for the define_method.  <sigh>
        fake_file_class = @fake_file_class = klass.new(flock_return)
        Geminabox::Server.file_class = fake_file_class
        @mock_file = fake_file_class.mock_file
      end

      def restore_server
        Geminabox.http_adapter = HttpClientAdapter.new
        Geminabox.allow_remote_failure = false
        Geminabox::Server.file_class = File
      end
    end

    describe 'Geminabox::VERSION' do
      def test_version
        assert_equal 'constant', (defined?(Geminabox::VERSION))
      end
    end

    describe "#with_rlock" do
      include PrepServer

      after { restore_server }

      def do_call
        server.send(:with_rlock) { @called = true }
      end

      def test_it_yields
        prep_server(FileOpenYields, true)
        do_call
        assert_equal true, @called
      end

      def test_it_blows_up_if_it_cannot_obtain_lock
        prep_server(FileOpenYields, false)
        assert_raises(ReentrantFlock::AlreadyLocked) { do_call }
      end

      def test_it_calls_File_open_with_correct_args
        prep_server(FileOpenNoYield)
        do_call
        assert_equal Geminabox.lockfile, fake_file_class.name
        assert_equal File::RDWR | File::CREAT, fake_file_class.mode
      end
    end

    describe "#serialize_update" do
      include PrepServer

      before do
        @server = Geminabox::Server.new.instance_variable_get(:@instance)
        def @server.args
          @args
        end
      end

      after { restore_server }

      def test_block_passed_to_with_rlock
        def @server.with_rlock(&block)
          @args = block
        end

        blk = Proc.new { @called = true }
        @server.send(:serialize_update, &blk)
        assert_equal blk, @server.args
      end

      def test_alreadylocked_in_with_rlock_invokes_halt
        def @server.with_rlock(&block)
          raise ReentrantFlock::AlreadyLocked
        end

        def @server.halt(code, headers, message)
          @args = [code, headers, message]
        end

        @server.send(:serialize_update){}
        expected_args = [
          503,
          { 'Retry-After' => Geminabox.retry_interval.to_s },
          'Repository lock is held by another process'
        ]
        assert_equal expected_args, @server.args
      end
    end
  end
end
