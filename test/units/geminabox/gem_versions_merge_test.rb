require_relative '../../test_helper'

module Geminabox
  class GemVersionsMergeTest < Minitest::Test

    def test_merge_local_over_remote
      local = "created_at: 2021-06-27T16:14:36.466+0000\n---\ntest-gem 0.0.1 91643f56b430feed3f6725c91fcfac70\n"
      remote = "created_at: 2021-06-27T16:14:36.466+0000\n---\ntest-gem 0.0.5 e7218e76477e2137355d2e7ded094925\n"
      expected = local
      assert_equal expected, GemVersionsMerge.merge(local, remote, strategy: :local_gems_take_precedence_over_remote_gems)
    end

    def test_merge_remote_over_local
      local = "created_at: 2021-06-27T16:14:36.466+0000\n---\ntest-gem 0.0.1 91643f56b430feed3f6725c91fcfac70\n"
      remote = "created_at: 2021-06-27T16:14:36.466+0000\n---\ntest-gem 0.0.5 e7218e76477e2137355d2e7ded094925\n"
      expected = remote
      assert_equal expected, GemVersionsMerge.merge(local, remote, strategy: :remote_gems_take_precedence_over_local_gems)
    end

    def test_timestamp_local_over_remote
      local = "created_at: 2021-06-27T16:14:36.466+0000\n---\ntest-gem 0.0.1 91643f56b430feed3f6725c91fcfac70\n"
      remote = "created_at: 2020-06-27T16:14:36.466+0000\n---\ntest-gem 0.0.5 e7218e76477e2137355d2e7ded094925\n"
      expected = local[/created_at:\s(\S+)\s/]
      timestamp = GemVersionsMerge.merge(local, remote, strategy: :local_gems_take_precedence_over_remote_gems)[/created_at:\s(\S+)\s/]
      assert_equal expected, timestamp
    end

    def test_timestamp_remote_over_local
      local = "created_at: 2021-06-27T16:14:36.466+0000\n---\ntest-gem 0.0.1 91643f56b430feed3f6725c91fcfac70\n"
      remote = "created_at: 2020-06-27T16:14:36.466+0000\n---\ntest-gem 0.0.5 e7218e76477e2137355d2e7ded094925\n"
      expected = local[/created_at:\s(\S+)\s/]
      timestamp = GemVersionsMerge.merge(local, remote, strategy: :remote_gems_take_precedence_over_local_gems)[/created_at:\s(\S+)\s/]
      assert_equal expected, timestamp
    end

    def test_merge_multiple_local_over_remote
      local = "created_at: 2021-06-27T16:14:36.466+0000\n---\ntest-gem1 0.0.1 91643f56b430feed3f6725c91fcfac70\ntest-gem2 0.0.1 75f21fffe3703239725b848bf82d3143\n"
      remote = "created_at: 2021-06-27T16:14:36.466+0000\n---\ntest-gem2 0.0.2 c379eb80dd9b53e8b99e5507c8aebcb0\ntest-gem3 0.0.1 4e58bc03e301f704950410b713c20b69\ntest-gem4 0.0.1 e00c558565f7b03a438fbd93d854b7de\n"
      merged = GemVersionsMerge.merge(local, remote, strategy: :local_gems_take_precedence_over_remote_gems)
      expected = "created_at: 2021-06-27T16:14:36.466+0000\n---\n" \
                 "test-gem2 0.0.1 75f21fffe3703239725b848bf82d3143\n" \
                 "test-gem3 0.0.1 4e58bc03e301f704950410b713c20b69\n" \
                 "test-gem4 0.0.1 e00c558565f7b03a438fbd93d854b7de\n" \
                 "test-gem1 0.0.1 91643f56b430feed3f6725c91fcfac70\n"
      assert_equal expected, merged
    end

    def test_merge_multiple_remote_over_local
      local = "created_at: 2021-06-27T16:14:36.466+0000\n---\ntest-gem1 0.0.1 91643f56b430feed3f6725c91fcfac70\ntest-gem2 0.0.1 75f21fffe3703239725b848bf82d3143\n"
      remote = "created_at: 2021-06-27T16:14:36.466+0000\n---\ntest-gem2 0.0.2 c379eb80dd9b53e8b99e5507c8aebcb0\ntest-gem3 0.0.1 4e58bc03e301f704950410b713c20b69\ntest-gem4 0.0.1 e00c558565f7b03a438fbd93d854b7de\n"
      merged = GemVersionsMerge.merge(local, remote, strategy: :remote_gems_take_precedence_over_local_gems)
      expected = "created_at: 2021-06-27T16:14:36.466+0000\n---\n" \
                 "test-gem1 0.0.1 91643f56b430feed3f6725c91fcfac70\n" \
                 "test-gem2 0.0.2 c379eb80dd9b53e8b99e5507c8aebcb0\n" \
                 "test-gem3 0.0.1 4e58bc03e301f704950410b713c20b69\n" \
                 "test-gem4 0.0.1 e00c558565f7b03a438fbd93d854b7de\n"
      assert_equal expected, merged
    end

  end
end
