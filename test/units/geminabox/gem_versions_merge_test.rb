require_relative '../../test_helper'

module Geminabox
  class GemVersionsMergeTest < Minitest::Test

    def setup
      clean_data_dir
    end

    def test_merge_local_over_remote
      local = "created_at: 2021-07-27T16:14:36.466+0000\n---\ntest-gem 0.0.1 91643f56b430feed3f6725c91fcfac70\n"
      remote = "created_at: 2021-06-27T16:14:36.466+0000\n---\n" \
               "test-gem 0.0.5 e7218e76477e2137355d2e7ded094925\n"
      expected = "created_at: 2021-07-27T16:14:36.466+0000\n---\n" \
                 "test-gem 0.0.1 91643f56b430feed3f6725c91fcfac70\n" \
                 "test-gem 0.0.5 e7218e76477e2137355d2e7ded094925\n"
      assert_equal expected, GemVersionsMerge.new(local, remote).call
    end

    def test_timestamp_local_over_remote
      local = "created_at: 2021-06-27T16:14:36.466+0000\n---\ntest-gem 0.0.1 91643f56b430feed3f6725c91fcfac70\n"
      remote = "created_at: 2020-06-27T16:14:36.466+0000\n---\ntest-gem 0.0.5 e7218e76477e2137355d2e7ded094925\n"
      expected = local[/created_at:\s(\S+)\s/]
      timestamp = GemVersionsMerge.new(local, remote).call[/created_at:\s(\S+)\s/]
      assert_equal expected, timestamp
    end

    def test_merge_multiple_local_over_remote
      local = "created_at: 2021-06-27T16:14:36.466+0000\n---\ntest-gem1 0.0.1 91643f56b430feed3f6725c91fcfac70\ntest-gem2 0.0.1 75f21fffe3703239725b848bf82d3143\n"
      remote = "created_at: 2021-06-27T16:14:36.466+0000\n---\ntest-gem2 0.0.2 c379eb80dd9b53e8b99e5507c8aebcb0\ntest-gem3 0.0.1 4e58bc03e301f704950410b713c20b69\ntest-gem4 0.0.1 e00c558565f7b03a438fbd93d854b7de\n"
      merged = GemVersionsMerge.new(local, remote).call
      expected = "created_at: 2021-06-27T16:14:36.466+0000\n---\n" \
                 "test-gem1 0.0.1 91643f56b430feed3f6725c91fcfac70\n" \
                 "test-gem2 0.0.1 75f21fffe3703239725b848bf82d3143\n" \
                 "test-gem2 0.0.2 c379eb80dd9b53e8b99e5507c8aebcb0\n" \
                 "test-gem3 0.0.1 4e58bc03e301f704950410b713c20b69\n" \
                 "test-gem4 0.0.1 e00c558565f7b03a438fbd93d854b7de\n"
      assert_equal expected, merged
    end

    def test_merge_multiple_remote_version_entries_are_merged
      local = <<~LOCAL
        created_at: 2021-06-27T16:14:36.466+0000
        ---
        test-gem1 0.0.1 91643f56b430feed3f6725c91fcfac70
        test-gem2 0.0.1 75f21fffe3703239725b848bf82d3143
      LOCAL
      remote = <<~REMOTE
        created_at: 2021-06-27T16:14:36.466+0000
        ---
        test-gem3 0.0.1,0.0.2 c379eb80dd9b53e8b99e5507c8aebcb0
        test-gem3 1.0.0 4e58bc03e301f704950410b713c20b69
      REMOTE

      merged = GemVersionsMerge.new(local, remote).call
      expected = <<~EXPECTED
        created_at: 2021-06-27T16:14:36.466+0000
        ---
        test-gem1 0.0.1 91643f56b430feed3f6725c91fcfac70
        test-gem2 0.0.1 75f21fffe3703239725b848bf82d3143
        test-gem3 0.0.1,0.0.2 c379eb80dd9b53e8b99e5507c8aebcb0
        test-gem3 1.0.0 4e58bc03e301f704950410b713c20b69
      EXPECTED

      assert_equal expected, merged
    end

    def test_merge_multiple_removes_verions_with_same_name_different_digests
      local = "created_at: 2021-06-27T16:14:36.466+0000\n---\ntest-gem1 0.0.1 91643f56b430feed3f6725c91fcfac70\ntest-gem2 0.0.1 75f21fffe3703239725b848bf82d3143\n"
      remote = "created_at: 2021-06-27T16:14:36.466+0000\n---\ntest-gem1 0.0.1 91643f56b430feed3f6725c91fcfac70\ntest-gem1 0.0.1 75f21fffe3703239725b848bf82d3143\n"
      merged = GemVersionsMerge.new(local, remote).call
      expected = "created_at: 2021-06-27T16:14:36.466+0000\n---\n" \
                 "test-gem1 0.0.1 75f21fffe3703239725b848bf82d3143\n" \
                 "test-gem1 0.0.1 91643f56b430feed3f6725c91fcfac70\n" \
                 "test-gem2 0.0.1 75f21fffe3703239725b848bf82d3143\n"
      assert_equal expected, merged
    end

  end
end
