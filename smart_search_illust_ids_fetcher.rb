require 'rubygems'
require 'eventmachine'
require 'em-http-request'
require 'pixiv'

require_relative 'utils'

# 直近のブックマークの中から適当なタグを選んで検索し、そのイラストIDを取得する
#
class SmartSearchIllustIdsFetcher
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
      fetch_illusts(illust_ids) {|bookmarked_illusts|
        calc_interest_tags(bookmarked_illusts) {|interest_tags|
          multi = EM::MultiRequest.new

          interest_tags.each {|tag|
            (1..3).each {|p|
              url = Pixiv::SearchResultList.url(tag, page: p)
              multi.add({
                name: :smart_search,
                tag: tag,
                page: p,
                score_threshold: 1000
              }, EM::HttpRequest.new(url, @con_opts).get(@req_opts))
            }
          }

          multi.callback {
            log_multi_stat(multi)
            multi.responses[:callback].each {|name, conn|
              illust_ids = extract_illust_ids(conn.response)
              illust_ids.each {|illust_id|
                @jobs[illust_id] = name
              }
            }
            yield @jobs
          }
        }
      }
    }

    self
  end

  def fetch_bookmarked_illust_ids
    me = @pixiv.member
    illust_ids = []
    (1..1).each {|page|
        me.bookmark_list(page).illust_hashes.each {|attrs|
          illust_ids << attrs[:illust_id]
        }
    }
    yield illust_ids
  end

  def fetch_illusts(illust_ids)
    illusts = []
    EM::Iterator.new(illust_ids, 10).each(proc{|illust_id, iter|
      url = Pixiv::Illust.url(illust_id)
      http = EM::HttpRequest.new(url, @con_opts).get(@req_opts)
      http.callback {
        doc = Nokogiri::HTML(http.response)
        illust = Pixiv::Illust.new(doc)
        illusts << illust
        print '.'
        iter.next
      }
      http.errback {
        p http.error
        iter.next
      }
    }, proc{
      yield illusts
    })
  end

  def calc_interest_tags(illusts)
    tags = []
    illusts.each {|illust|
      tags += illust.tag_names
    }
    tags -= ['R-18', 'R-18G']
    count = {}
    tags.each {|tag|
      count[tag] ? count[tag] += 1 : count[tag] = 1
    }
    sorted = count.sort_by{|k,v| -v}.map{|e| e[0]}
    start = (sorted.size * 0.01).round
    finish = (sorted.size * 0.03).round

    interest_tags = sorted[start..finish]

    yield interest_tags
  end
end
