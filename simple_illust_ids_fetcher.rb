require 'rubygems'
require 'eventmachine'
require 'em-http-request'
require 'pixiv'

require_relative 'utils'

# 単純に取得できるイラストIDを取得する
class SimpleIllustIdsFetcher < EM::DefaultDeferrable
  include Utils

  attr_reader :illust_ids

  def initialize(config, pixiv, options)
    @config = config
    @pixiv = pixiv
    @options = options

    @illust_ids = []
  end

  def fetch
    multi = EM::MultiRequest.new
    # bookmark_new_illust
    (1..5).each do |p|
      multi.add({task: :bookmark_new_illust, page: p}, EM::HttpRequest.new("#{Pixiv::ROOT_URL}/bookmark_new_illust.php?p=#{p}").get(@options))
    end
    # search
    @config[:favorite_tags].each do |tag|
      (1..3).each do |p|
        multi.add({task: :search, page: p, tag: tag}, EM::HttpRequest.new(Pixiv::SearchResultList.url(tag[:query], page: p)).get(@options))
      end
    end
    # ranking
    ['daily', 'daily_r18', 'r18g'].each do |mode|
      url = "#{Pixiv::ROOT_URL}/ranking.php?mode=#{mode}"
      multi.add({task: :ranking, mode: mode}, EM::HttpRequest.new(url).get(@options))
    end

    multi.callback do
      multi.responses[:callback].each do |name, conn|
        @illust_ids += extract_illust_ids(conn.response)
      end
      succeed(@illust_ids)
    end

    self
  end
end
