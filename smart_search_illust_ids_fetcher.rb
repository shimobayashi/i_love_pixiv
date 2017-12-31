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
    (1..3).each {|p|
      url = "#{Pixiv::ROOT_URL}/bookmark.php?rest=show&p=#{p}"
      page = @pixiv.agent.get url
      illust_ids.concat(extract_illust_ids(page.content))
    }
    p 'illust_ids:'
    p illust_ids
    yield illust_ids
  end

  def fetch_illusts(illust_ids)
    illusts = []
    EM::Iterator.new(illust_ids, 2).each(proc{|illust_id, iter|
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
    tag_weight = Hash.new(0)
    sum_weight = 0
    illusts.each {|illust|
      sum_weight += illust.tag_names.size.to_f
      for tag in illust.tag_names
        tag_weight[tag] += 1.0
      end
      tags += illust.tag_names
    }
    tags.uniq!
    tags -= ['R-18', 'R-18G']

    uri = URI.parse("#{ENV['VIMAGE_ROOT']}idf")
    json = JSON.parse(Net::HTTP.get(uri))

    tag_tfidf = {}
    tags.each {|tag|
      tf = tag_weight[tag] / sum_weight
      idf = json[tag] ? json[tag]['idf'] : 0 # IDFリストに含まれていないやつはとりあえず無視する方向で0とする
      tfidf = tf * idf

      tag_tfidf[tag] = tfidf
    }
    #p tag_tfidf

    sorted = tag_tfidf.sort_by{|k,v| -v}.map{|e| e[0]} 
    #p sorted
    start = (sorted.size * 0.01).round
    finish = (sorted.size * 0.03).round

    interest_tags = sorted[start..finish]
    #p interest_tags

    yield interest_tags
  end
end
