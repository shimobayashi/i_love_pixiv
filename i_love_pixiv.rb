require 'rubygems'
require 'pit'
require 'pixiv'
require 'eventmachine'
require 'nokogiri'

require_relative 'simple_illust_ids_fetcher'
require_relative 'famous_illust_ids_fetcher'
require_relative 'utils'

class ILovePixiv
  include Utils

  def initialize
    @config = Pit.get('pixiv.net', :require => {
      id: 'your_id',
      password: 'your_password',
      favorite_tags: [{query: 'your_query', score_threshold: 100}],
    })
    @pixiv = Pixiv.client(@config[:id], @config[:password]) {|agent|
      agent.user_agent_alias = 'Mac Safari'
    }
    @con_opts = {} #{proxy: {host: '127.0.0.1', port: 9050, type: :socks5}}
    @req_opts = {head: {cookie: @pixiv.agent.cookie_jar.to_a}}
  end

  def run
    EM.run {
      puts 'fetch_jobs:'
      fetch_jobs {|jobs|
        puts 'filter_jobs_to_illusts:'
        filter_jobs_to_illusts(jobs) {|illusts|
          p illusts.map{|e| e.title}
          EM.stop
        }
      }
    }
  end

  def fetch_jobs
    multi = EM::MultiRequest.new

    multi.add :simple_illust_ids_fetcher, SimpleIllustIdsFetcher.new(@config, @pixiv, @con_opts, @req_opts).fetch
    multi.add :famous_illust_ids_fetcher, FamousIllustIdsFetcher.new(@config, @pixiv, @con_opts, @req_opts).fetch

    multi.callback {
      jobs = multi.responses[:callback].values.map{|e| e.jobs}.inject{|memo, item| memo.merge(item)} # 上書きする可能性あり
      yield jobs
    }
  end

  def filter_jobs_to_illusts(jobs)
    illust_ids = jobs.keys
    illusts = []
    EM::Iterator.new(illust_ids, 20).each(proc{|illust_id, iter|
      url = Pixiv::Illust.url(illust_id)
      http = EM::HttpRequest.new(url, @con_opts).get(@req_opts)
      http.callback {
        doc = Nokogiri::HTML(http.response)
        illust = Pixiv::Illust.new(doc)
        name = jobs[illust_id]
        illusts << illust if illust.score >= (name[:score_threshold] || 0)
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
end

ILovePixiv.new.run
