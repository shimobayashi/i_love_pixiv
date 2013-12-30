# -*- encoding: utf-8 -*-

require 'rubygems'
require 'pit'
require 'pixiv'
require 'eventmachine'
require 'nokogiri'

require_relative 'simple_illust_ids_fetcher'
require_relative 'famous_illust_ids_fetcher'
require_relative 'utils'
require_relative 'pirage'

module Pixiv
  class Illust
    lazy_attr_reader(:illust_id) { at!('link[rel="alternate"][hreflang="ja"]')[:href][/illust_id=(\d+)/, 1].to_i }
    lazy_attr_reader(:member_name) {
      at!('title').inner_text[%r!「#{Regexp.escape(title)}」/「(.+)」の(?:イラスト|漫画) \[pixiv\]!, 1]
    }
  end
end

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
    @con_opts = {} #{proxy: {host: '127.0.0.1', port: 9050, type: :socks5}} # 本当は個別に設定したいが、上手く動かない
    @req_opts = {
      head: {
        'user-agent' => @pixiv.agent.user_agent,
        'accept-language' => 'ja',
        'referer' => 'http://www.pixiv.net/mypage.php',
        'cookie' => @pixiv.agent.cookie_jar.to_a,
      }
    }
  end

  def run
    posted_illust_ids = Marshal.load(open('posted_illust_ids.marshal')) rescue []
    #p posted_illust_ids
    at_exit {
      puts 'Saving posted illust ids'
      #p posted_illust_ids
      Marshal.dump(posted_illust_ids, open('posted_illust_ids.marshal', 'w'))
    }

    EM.run {
      puts 'fetch_jobs:'
      fetch_jobs {|jobs|
        puts 'filter_jobs_to_illusts:'
        #jobs = Hash[jobs.to_a.sample(4)]
        #p jobs
        filter_jobs_to_illusts(jobs, posted_illust_ids) {|illusts|
          puts 'post_illust_to_pirage:'
          post_illust_to_pirage(illusts) {|posted_illusts|
            posted_illust_ids += posted_illusts.map{|e| e.illust_id}
            p illusts.map{|e| e.title}
            EM.stop
          }
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

  def filter_jobs_to_illusts(jobs, posted_illust_ids)
    illust_ids = jobs.keys - posted_illust_ids
    illusts = []
    EM::Iterator.new(illust_ids, 10).each(proc{|illust_id, iter|
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

  def post_illust_to_pirage(illusts)
    posted_illusts = []
    EM::Iterator.new(illusts, 10).each(proc{|illust, iter|
      url = illust.medium_image_url
      http = EM::HttpRequest.new(url, @con_opts).get(@req_opts)
      http.callback {
        #XXX
        tags = illust.tag_names
        tags << 'R-00' if (['R-18', 'R-18G'] & illust.tag_names).length > 0
        p Pirage.post(
          illust.member_name || '',
          illust.title,
          illust.url,
          tags,
          illust.title,
          http.response.force_encoding('UTF-8')

        )
        posted_illusts << illust
        print '.'
        iter.next
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

ILovePixiv.new.run
