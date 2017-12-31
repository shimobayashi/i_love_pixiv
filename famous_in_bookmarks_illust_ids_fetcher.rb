require 'eventmachine'
require 'em-http-request'
require 'json'

require_relative 'utils'

# ブックマークしたイラストのレコメンドから重複するイラストIDを取得する
#
class FamousInBookmarksIllustIdsFetcher
  include Utils

  attr_reader :jobs

  def initialize(config, pixiv, con_opts, req_opts)
    @config = config
    @pixiv = pixiv
    @con_opts = con_opts
    @req_opts = req_opts

    @jobs = {}
  end

  def fetch
    fetch_bookmarked_illust_ids {|illust_ids|
      #p illust_ids
      fetch_jobs(illust_ids) {|jobs|
        @jobs = jobs
        yield @jobs
      }
    }

    self
  end

  def fetch_bookmarked_illust_ids
    illust_ids = []
    (1..2).each {|p|
      url = "#{Pixiv::ROOT_URL}/bookmark.php?rest=hide&p=#{p}"
      page = @pixiv.agent.get url
      illust_ids.concat(extract_illust_ids(page.content))
    }
    p 'illust_ids:'
    p illust_ids
    yield illust_ids
  end

  def fetch_jobs(illust_ids)
    page = @pixiv.agent.get 'http://www.pixiv.net/search_user.php'
    tt = page.at('input[name="tt"]')[:value]

    count_by_illust_id = Hash.new(0)
    EM::Iterator.new(illust_ids, 2).each(proc{|illust_id, iter|
      url = "http://www.pixiv.net/rpc/recommender.php?type=illust&sample_illusts=#{illust_id}&num_recommendations=300&tt=#{tt}"
      http = EM::HttpRequest.new(url, @con_opts).get(@req_opts)
      http.callback {
        json = JSON.load(http.response)
        json['recommendations'].each {|illust_id|
          count_by_illust_id[illust_id] += 1
        }
        print '.'
        iter.next
      }
      http.errback {
        p http.error
        iter.next
      }
    }, proc{
      illust_ids = count_by_illust_id.reject{|k, v| v < 2}.keys
      jobs = {}
      illust_ids.each {|illust_id|
        jobs[illust_id] = {name: :famous_in_bookmarks, score_threshold: 100}
      }
      yield jobs
    })
  end
end
