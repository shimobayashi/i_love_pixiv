require 'rubygems'
require 'eventmachine'
require 'em-http-request'
require 'pixiv'

require_relative 'utils'

# お気に入りイラストの著者のイラストの中から興味がありそうなイラストIDを取得する
class InterestInBookmarkedAuthor
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
    fetch_bookmarked_member_ids {|member_ids|
      fetch_illust_ids(member_ids) {|illust_ids|
        fetch_jobs(illust_ids) {|jobs|
          @jobs = jobs
          yield @jobs
        }
      }
    }

    self
  end

  def fetch_bookmarked_member_ids
    me = @pixiv.member
    member_ids = []
    (1..2).each {|p|
      url = "#{Pixiv::ROOT_URL}/bookmark.php?rest=show&p=#{p}"
      page = @pixiv.agent.get url
      member_ids.concat(extract_member_ids(page.content))
    }
    member_ids.uniq!
    p 'member_ids:'
    p member_ids
    yield member_ids 
  end

  def fetch_illust_ids(member_ids)
    urls = []
    member_ids.each {|member_id|
      (1..2).each {|p|
        url = "#{Pixiv::ROOT_URL}/member_illust.php?id=#{member_id}&type=all&p=#{p}"
        urls << url
      }
    }

    illust_ids = []
    EM::Iterator.new(urls, 10).each(proc{|url, iter|
      http = EM::HttpRequest.new(url, @con_opts).get(@req_opts)
      http.callback {
        illust_ids.concat(extract_illust_ids(http.response))
        print '.'
        iter.next
      }
      http.errback {
        p http.error
        iter.next
      }
    }, proc{
      yield illust_ids
    })
  end

  def fetch_jobs(illust_ids)
    jobs = {}
    EM::Iterator.new(illust_ids, 10).each(proc{|illust_id, iter|
      url = Pixiv::Illust.url(illust_id)
      http = EM::HttpRequest.new(url, @con_opts).get(@req_opts)
      http.callback {
        doc = Nokogiri::HTML(http.response)
        illust = Pixiv::Illust.new(doc)

        # 今のところキャプションしか見てない
        @config[:interest_words].each {|word| # 雑に全部舐めてるので複数マッチするような場合上書きされる
          if illust.caption.include?(word[:query])
            jobs[illust_id] = {
              name: :interest_in_boormarked_author,
              score_threshold: word[:score_threshold],
            }
          end
        }

        print '.'
        iter.next
      }
      http.errback {
        p http.error
        iter.next
      }
    }, proc{
      yield jobs
    })
  end
end
