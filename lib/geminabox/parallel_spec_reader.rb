module Geminabox
  module ParallelSpecReader
    # Building the specs from the gem files is the most expensive part
    # of performing a full reindex. We speed it up a bit by
    # paralllelizing it using the 'parallel' gem.
    def map_gems_to_specs(gems)
      count = gems.count
      Gem.time "Read #{count} gem specifications" do
        n = Geminabox.workers

        title = "Reading #{count} gem specifications"
        progressbar_options = Gem::DefaultUserInteraction.ui.outs.tty? && n > 1 && {
          title: title,
          total: count,
          format: '%t %b',
          progress_mark: '.'
        }
        say title unless progressbar_options

        fork_type = {in_processes: n}
        fork_type = {in_threads: n} if RUBY_PLATFORM == 'x64-mingw32'
        Parallel.map(gems, progress: progressbar_options, **fork_type) do |gemfile|
          map_gem_file_to_spec(gemfile)
        end.compact
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
