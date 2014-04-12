require 'rubygems'
require 'eventmachine'
require 'em-http-request'
require 'pixiv'

require_relative 'utils'

# 複数Followingがお気に入り登録しているイラストIDを取得する
#
class FamousIllustIdsFetcher < EM::DefaultDeferrable
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
    fetch_following_member_ids {|member_ids|
      fetch_jobs(member_ids) {|jobs|
        @jobs = jobs
        succeed @jobs
      }
    }

    self
  end

  def fetch_following_member_ids
    last_page = @pixiv.agent.get("#{Pixiv::ROOT_URL}/bookmark.php?type=user").search('.pages:first-child li:nth-last-child(2) a').inner_text.to_i

    multi = EM::MultiRequest.new
    (1..last_page).each {|p|
      url = "#{Pixiv::ROOT_URL}/bookmark.php?type=user&rest=show&p=#{p}"
      multi.add(p, EM::HttpRequest.new(url, @con_opts).get(@req_opts))
    }

    multi.callback {
      log_multi_stat(multi)
      member_ids = []
      multi.responses[:callback].each {|name, conn|
        doc = Nokogiri::HTML(conn.response)
        member_ids += doc.search('.userdata a').map{|e| $1 if e[:href] =~ /id=(\d+)/}
      }
      yield member_ids
    }
  end

  def fetch_jobs(member_ids)
    urls = []
    member_ids.each {|member_id|
      (1..5).each {|p|
        url = "#{Pixiv::ROOT_URL}/bookmark.php?id=#{member_id}&rest=show&p=#{p}"
        urls << url
      }
    }

    count_by_illust_id = Hash.new(0)
    EM::Iterator.new(urls, 10).each(proc{|url, iter|
      http = EM::HttpRequest.new(url, @con_opts).get(@req_opts)
      http.callback {
        extract_illust_ids(http.response).each {|illust_id|
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
        jobs[illust_id] = {name: :famous, score_threshold: 100}
      }
      yield jobs
    })
  end
end
