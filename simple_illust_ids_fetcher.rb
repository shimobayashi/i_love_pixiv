require 'rubygems'
require 'eventmachine'
require 'em-http-request'
require 'pixiv'

require_relative 'utils'

# 単純に取得できるイラストIDを取得する
#
class SimpleIllustIdsFetcher
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
    tasks = []
    # bookmark_new_illust
    (1..5).each {|p|
      url = "#{Pixiv::ROOT_URL}/bookmark_new_illust.php?p=#{p}"
      tasks << {
        url: url,
        name: :bookmark_new_illust,
        page: p,
        score_threshold: 100,
      }
    }
    # search
    @config[:favorite_tags].each {|tag|
      (1..10).each {|p|
        url = Pixiv::SearchResultList.url(tag[:query], page: p)
        tasks << {
          url: url,
          name: :search,
          tag: tag,
          page: p,
          score_threshold: tag[:score_threshold],
        }
      }
    }
    # ranking
    #[
    #  {query: 'daily', score_threshold: 80000},
    #  {query: 'daily_r18', score_threshold: 10000},
    #  {query: 'r18g', score_threshold: 4000},
    #].each {|mode|
    #  url = "#{Pixiv::ROOT_URL}/ranking.php?mode=#{mode[:query]}"
    #  multi.add({
    #    name: :ranking,
    #    mode: mode,
    #    score_threshold: mode[:score_threshold],
    #  }, EM::HttpRequest.new(url, @con_opts).get(@req_opts))
    #}

    EM::Iterator.new(tasks, 10).each(proc{|task, iter|
      url = task[:url]
      name = task[:name]
      http = EM::HttpRequest.new(url, @con_opts).get(@req_opts)
      http.callback {
        illust_ids = extract_illust_ids(http.response)
        illust_ids.each {|illust_id|
          @jobs[illust_id] = task # 上書きする可能性あり
        }
        print '.'
        iter.next
      }
      http.errback {
        p http.error
        iter.next
      }
    }, proc{
      yield @jobs
    })

    self
  end
end
