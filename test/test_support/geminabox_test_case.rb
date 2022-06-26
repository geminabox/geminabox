require 'minitest/unit'
require 'timeout'
require 'socket'
require 'rack'
require 'uri'
require 'fileutils'
require 'tempfile'
require 'webrick'
require 'webrick/https'
require 'logger'
require 'rack/auth/abstract/handler'
require 'rack/auth/abstract/request'

class Geminabox::TestCase < Minitest::Test
  class << self
    # DSL
    def url(url = nil)
      @url ||= url || "http://localhost/"
    end

    def ssl(ssl = nil)
      if ssl.nil?
        @ssl
      else
        @ssl = ssl
      end
    end

    def data(data = nil)
      @data ||= data || File.join(Dir.tmpdir, "geminabox-test-data")
    end

    def gem_permissions
      0644
    end

    def app(&block)
      @app = block || @app || lambda{|builder| run Geminabox::Server }
    end

    def to_app
      Rack::Builder.app(&app)
    end

    def should_fetch_gem(gemname = :example, *args)
      test("can fetch #{gemname}") do
        assert_can_fetch(gemname, *args)
      end
    end

    def should_push_gem(gemname = :example, *args)
      test("can push #{gemname}") do
        assert_can_push(gemname, *args)
        gem_path = File.join(config.data, "gems", File.basename(gem_file(gemname, *args)) )
        assert File.exist?( gem_path ), "Gemfile not in data dir."
        assert File.stat(gem_path).mode.to_s(8).match(/#{config.gem_permissions.to_s(8)}$/), "Gemfile has incorrect permissions."
      end
    end

    def should_push_gem_over_gemcutter_api(gemname = :example, *args)
      test("can push #{gemname}") do
        gem_file = gem_file(gemname, *args)
        gemcutter_push(gem_file)
        gem_path = File.join(config.data, "gems", File.basename(gem_file) )
        assert File.exist?( gem_path ), "Gemfile not in data dir."
        assert File.stat(gem_path).mode.to_s(8).match(/#{config.gem_permissions.to_s(8)}$/), "Gemfile has incorrect permissions."
      end
    end

    def should_yank_gem_over_gemcutter_api(gemname = :example, version = '1.0.0', *args)
      test("can yank #{gemname}") do
        gem_file = gem_file(gemname, *args)
        gemcutter_push(gem_file)
        gem_path = File.join(config.data, "gems", File.basename(gem_file) )
        assert File.exist?( gem_path ), "Gemfile not in data dir."
        gemcutter_yank(gemname, version)
        gem_path = File.join(config.data, "gems", File.basename(gem_file) )
        assert !File.exist?( gem_path ), "Gemfile in data dir."
      end
    end

    def url_with_port(port)
      uri = URI.parse url
      uri.port = port
      uri.to_s
    end

  end

  def setup
    super
    start_app!
  end

  def teardown
    stop_app!
    super
  end



  def config
    self.class
  end

  def url_for(path)
    @url_with_port ||= config.url_with_port(@test_server_port).gsub(%r{/$}, "")
    path = "/#{path}" unless path.start_with? "/"
    @url_with_port + path
  end

  FAKE_HOME = File.join(Dir.tmpdir, "geminabox-test-home")
  def self.setup_fake_home!
    return if @setup_fake_home
    @setup_fake_home = true
    FileUtils.rm_rf(FAKE_HOME)
    FileUtils.mkdir_p("#{FAKE_HOME}/gems")
    FileUtils.mkdir_p("#{FAKE_HOME}/specifications")

    FileUtils.ln_s(fixture("geminabox-9999.0.0.gemspec"), "#{FAKE_HOME}/specifications/geminabox-9999.0.0.gemspec")
    FileUtils.ln_s(fixture("../.."), "#{FAKE_HOME}/gems/geminabox-9999.0.0.gem")
  end

  def without_bundler
    if defined?(Bundler)
      if Bundler.respond_to?(:with_unbundled_env)
        Bundler.with_unbundled_env { yield }
      else
        # NOTE: Bundler.with_clean_env is deprecated since bundler v2
        Bundler.with_clean_env { yield }
      end
    else
      yield
    end
  end

  def execute(command)
    output = ""
    IO.popen(command, "r") do |io|
      data = io.read
      output << data
    end
    output
  end

  def fix_fixture_permissions!
    File.chmod 0600, FIXTURES_PATH.join('fake_home_path/.gem/credentials')
  end

  def gem_fetch(gemname)
    Geminabox::TestCase.setup_fake_home!
    fix_fixture_permissions!
    home = FIXTURES_PATH.join('fake_home_path')
    command = "GEM_HOME=#{FAKE_HOME} HOME=#{home} gem fetch #{gemname} --clear-sources --source '#{config.url_with_port(@test_server_port)}' 2>&1"
    without_bundler { execute(command) }
  end

  def gemcutter_push(gemfile)
    Geminabox::TestCase.setup_fake_home!
    fix_fixture_permissions!
    home = FIXTURES_PATH.join('fake_home_path')
    command = "GEM_HOME=#{FAKE_HOME} HOME=#{home} gem push #{gemfile} --host '#{config.url_with_port(@test_server_port)}' 2>&1"
    without_bundler { execute(command) }
  end

  def gemcutter_yank(gemname, version)
    Geminabox::TestCase.setup_fake_home!
    fix_fixture_permissions!
    home = FIXTURES_PATH.join('fake_home_path')
    command = "GEM_HOME=#{FAKE_HOME} HOME=#{home} gem yank #{gemname} -v #{version} --host '#{config.url_with_port(@test_server_port)}' 2>&1"
    without_bundler { execute(command) }
  end

  def geminabox_push(gemfile)
    Geminabox::TestCase.setup_fake_home!
    command = "GEM_HOME=#{FAKE_HOME} gem inabox #{gemfile} -g '#{config.url_with_port(@test_server_port)}' 2>&1"
    execute(command)
  end

  def assert_can_fetch(gemname = :example, *args)
    geminabox_push(gem_file(gemname, *args))
    assert_match( /Downloaded #{gemname}/, gem_fetch(gemname))
  end

  def assert_can_push(gemname = :example, *args)
    assert_match( /Gem .* received and indexed./, geminabox_push(gem_file(gemname, *args)))
  end

  def find_free_port
    server = TCPServer.new('localhost', 0)
    port = server.addr[1]
    server.close
    port
  end

  FIXTURES_PATH = Pathname.new(File.expand_path("../../fixtures", __FILE__))
  def load_fixture_data_dir(name)
    path = FIXTURES_PATH.join("#{name}.fixture")
    FileUtils.rm_rf config.data
    FileUtils.mkdir_p config.data

    Dir.chdir config.data do
      system "tar", "-xf", path.to_s
    end
  end

  def cache_fixture_data_dir(name)
    path = FIXTURES_PATH.join("#{name}.fixture")
    if File.exist? path
      load_fixture_data_dir(name)
    else
      yield
      Dir.chdir config.data do
        system "tar", "-cf", path.to_s, *Dir.glob('{*,**/*}')
      end
    end
  end

  def log_to_stdout?
    Minitest::Reporters.reporters.any?{|reporter| reporter.instance_of?(Minitest::Reporters::SpecReporter)}
  end

  def start_app!
    clean_data_dir
    @test_server_port = find_free_port
    log_output = log_to_stdout? ? STDOUT : File::NULL
    server_options = {
      :app => config.to_app,
      :Port => @test_server_port,
      :AccessLog => [],
      :Logger => WEBrick::Log::new(log_output, Logger::INFO)
    }

    if config.ssl
      server_options.merge!(
        :SSLEnable => true,
        :SSLVerifyClient => OpenSSL::SSL::VERIFY_NONE,
        :SSLPrivateKey => OpenSSL::PKey::RSA.new(File.read(fixture("localhost.key"))),
        :SSLCertificate => OpenSSL::X509::Certificate.new(File.read(fixture("localhost.crt"))),
        :SSLCertName => [["CN", "localhost"]]
      )
    end

    @app_server = fork do
      SimpleCov.command_name SecureRandom.uuid
      Geminabox.data = config.data
      unless log_to_stdout?
        STDERR.reopen(File::NULL)
        STDOUT.reopen(File::NULL)
      end
      # Force kill our process to prevent ugly Webrick messages.
      Signal.trap(1) do
        # Data is only collected if we access the result.
        SimpleCov.result
        Process.kill(9, Process.pid)
      end
      Rack::Server.start(server_options)
    end

    Timeout.timeout(10) do
      begin
        Timeout.timeout(1) do
          TCPSocket.open("localhost", @test_server_port).close
        end
      rescue Errno::ECONNREFUSED
        sleep 0.10
        retry
      end
    end
  end

  def stop_app!
    Process.kill(1, @app_server) if @app_server
  end

  def gem_file(*args)
    GemFactory.gem_file(*args)
  end

end


