# -*- encoding: utf-8 -*-

require 'pit'
require 'pixiv'
require 'eventmachine'
require 'nokogiri'
require 'base64'

require_relative 'simple_illust_ids_fetcher'
require_relative 'famous_illust_ids_fetcher'
require_relative 'recommended_illust_ids_fetcher'
require_relative 'utils'
require_relative 'pixiv_gem_monkey_patch'
require_relative 'famous_in_bookmarks_illust_ids_fetcher'
require_relative 'smart_search_illust_ids_fetcher'
require_relative 'interest_in_bookmarked_author'

class ILovePixiv
  include Utils

  def initialize
    @config = Pit.get('pixiv.net', :require => {
      id: 'your_id',
      password: 'your_password',
      favorite_tags: [{query: 'your_query', score_threshold: 100}],
      interest_words: [{query: 'your_query', score_threshold: 100}],
    })
    @pixiv = Pixiv.client(@config[:id], @config[:password]) {|agent|
      agent.user_agent_alias = 'Mac Safari'
    }
    @con_opts = {:connect_timeout => 3, :inactivity_timeout => 5} #{proxy: {host: '127.0.0.1', port: 9050, type: :socks5}} # 本当は個別に設定したいが、上手く動かない
    @req_opts = {
      head: {
        'user-agent' => @pixiv.agent.user_agent,
        'accept-language' => 'ja',
        'referer' => 'http://www.pixiv.net/mypage.php',
        'cookie' => @pixiv.agent.cookie_jar.to_a,
      },
      redirects: 1, # https化の影響でhttpへのアクセスがリダイレクトされるようになっていた
    }
  end

  def run(task_name)
    posted_illust_ids = Marshal.load(open('posted_illust_ids.marshal')) rescue []
    #p posted_illust_ids
    at_exit {
      puts 'Saving posted illust ids'
      #p posted_illust_ids
      Marshal.dump(posted_illust_ids, open('posted_illust_ids.marshal', 'w'))
    }

    EM.run {
      puts 'fetch_jobs:'
      fetch_jobs(task_name) {|jobs|
        puts 'filter_jobs_to_illusts:'
        #jobs = Hash[jobs.to_a.sample(4)]
        #p jobs
        filter_jobs_to_illusts(jobs, posted_illust_ids) {|illusts|
          puts 'post_illust_to_vimage:'
          post_illust_to_vimage(illusts, jobs) {|posted_illusts|
            posted_illust_ids += posted_illusts.map{|e| e.illust_id}
            p posted_illusts.map{|e| e.title}
            EM.stop
          }
        }
      }
    }
  end

  def fetch_jobs(task_name)
    #jobs = {55215710 => {name: :test, score_threshold: 0}}
    #yield jobs
    #return

    jobs = {}
    puts 'task_name:'
    puts task_name
    #SimpleIllustIdsFetcher
    #FamousIllustIdsFetcher
    #RecommendedIllustIdsFetcher
    #FamousInBookmarksIllustIdsFetcher
    #SmartSearchIllustIdsFetcher
    Object.const_get(task_name).new(@config, @pixiv, @con_opts, @req_opts).fetch {|j|
      jobs.merge!(j)
      yield jobs
    }
  end

  def filter_jobs_to_illusts(jobs, posted_illust_ids)
    illust_ids = jobs.keys - posted_illust_ids
    illust_ids.shuffle! # 似たようなjobが固まると連続で失敗した時全滅したりフィードの最新が埋め尽くされたりされそうなので混ぜとく
    illusts = []
    EM::Iterator.new(illust_ids, 2).each(proc{|illust_id, iter|
      url = Pixiv::Illust.url(illust_id)
      http = EM::HttpRequest.new(url, @con_opts).get(@req_opts)
      http.callback {
        doc = Nokogiri::HTML(http.response)
        illust = Pixiv::Illust.new(doc)
        name = jobs[illust_id]
        illusts << illust if (illust.score >= (name[:score_threshold] || 0) rescue false)
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

  def post_illust_to_vimage(illusts, jobs)
    posted_illusts = []
    EM::Iterator.new(illusts, 2).each(proc{|illust, iter|
      url = illust.medium_image_url
      url = illust.small_image_url if url == 'https://source.pixiv.net/common/images/icon_ie.png' # うごイラだとこの画像になってしまうので雑に対応
      http = EM::HttpRequest.new(url, @con_opts).get(@req_opts)
      http.callback {
        medium_image = http.response.force_encoding('UTF-8')
        tags = illust.tag_names
        tags << 'R-00' if (['R-18', 'R-18G'] & illust.tag_names).length == 0
        tags << jobs[illust.illust_id][:name]

        #url = 'http://vimage.herokuapp.com/images/new'
        url = "#{ENV['VIMAGE_ROOT']}images/new"
        http = EM::HttpRequest.new(url, @con_opts.merge({ connect_timeout: 10, inactivity_timeout: 30 })).post(
          body: {
            title: "#{illust.member_name} - #{illust.title}",
            url: illust.url,
            tags: tags.join(' '),
            base64: Base64::encode64(medium_image),
          },
          head: @req_opts,
        )

        http.callback {
          posted_illusts << illust
          print '.'
          iter.next
        }
        http.errback {
          p http.error
          iter.next
        }
      }
      http.errback {
        p http.error
        iter.next
      }
    }, proc{
      yield posted_illusts
    })
  end
end

ILovePixiv.new.run(ARGV[0])
