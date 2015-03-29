require 'rubygems'
require 'eventmachine'
require 'em-http-request'
require 'pixiv'

require_relative 'utils'

# 単純に取得できるイラストIDを取得する
#
class SimpleIllustIdsFetcher < EM::DefaultDeferrable
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
    multi = EM::MultiRequest.new
    # bookmark_new_illust
    (1..5).each {|p|
      url = "#{Pixiv::ROOT_URL}/bookmark_new_illust.php?p=#{p}"
      multi.add({
        name: :bookmark_new_illust,
        page: p,
        score_threshold: 100,
      }, EM::HttpRequest.new(url, @con_opts).get(@req_opts))
    }
    # search
    @config[:favorite_tags].each {|tag|
      (1..10).each {|p|
        url = Pixiv::SearchResultList.url(tag[:query], page: p)
        multi.add({
          name: :search,
          tag: tag,
          page: p,
          score_threshold: tag[:score_threshold],
        }, EM::HttpRequest.new(url, @con_opts).get(@req_opts))
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

    multi.callback {
      log_multi_stat(multi)
      multi.responses[:callback].each {|name, conn|
        illust_ids = extract_illust_ids(conn.response)
        illust_ids.each {|illust_id|
          @jobs[illust_id] = name # 上書きする可能性あり
        }
      }
      succeed(@jobs)
    }

    self
  end
end
