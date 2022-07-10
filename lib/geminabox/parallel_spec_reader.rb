module Geminabox
  module ParallelSpecReader
    # Building the specs from the gem files is the most expensive part
    # of performing a full reindex. We speed it up a bit by
    # paralllelizing it using the 'parallel' gem.
    def map_gems_to_specs(gems)
      count = gems.count
      Gem.time "Read #{count} gem specifications" do
        mutex = Mutex.new
        progress_reporter = ui.progress_reporter(count, "Reading #{count} gem specifications", "Complete")

        specs = Parallel.map(gems, in_threads: 10) do |gemfile|
          map_gem_file_to_spec(gemfile).tap do
            mutex.synchronize { progress_reporter.updated(".") }
          end
        end.compact

        progress_reporter.done

        specs
      end
    end

    # Extract gem specification from gem file.
    def map_gem_file_to_spec(gemfile)
      spec = Gem::Package.new(gemfile).spec
      spec.loaded_from = gemfile

      spec.abbreviate
      spec.sanitize

      spec
    rescue StandardError => e
      msg = ["Unable to process #{gemfile}",
             "#{e.message} (#{e.class})",
             "\t#{e.backtrace.join "\n\t"}"].join("\n")
      alert_error msg
    end
  end
end
