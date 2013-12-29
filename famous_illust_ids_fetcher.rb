require 'rubygems'
require 'eventmachine'
require 'em-http-request'
require 'pixiv'

require_relative 'utils'

# 複数Followingがお気に入り登録しているイラストIDを取得する
class FamousIllustIdsFetcher < EM::DefaultDeferrable
  include Utils

  attr_reader :illust_ids

  def initialize(config, pixiv, options)
    @config = config
    @pixiv = pixiv
    @options = options

    @illust_ids = []
  end

  def fetch
    fetch_following_member_ids do |member_ids|
      multi = EM::MultiRequest.new
      member_ids.each do |member_id|
        (1..3).each do |p|
          multi.add([member_id, p], EM::HttpRequest.new("#{Pixiv::ROOT_URL}/bookmark.php?id=#{member_id}&rest=show&p=#{p}").get(@options))
        end
      end

      multi.callback do
        count_by_illust_id = Hash.new(0)
        multi.responses[:callback].each do |name, conn|
          extract_illust_ids(conn.response).each do |illust_id|
            count_by_illust_id[illust_id] += 1
          end
        end
        @illust_ids = count_by_illust_id.reject{|k, v| v < 2}.keys
        succeed(@illust_ids)
      end
    end

    self
  end

  def fetch_following_member_ids
    last_page = @pixiv.agent.get("#{Pixiv::ROOT_URL}/bookmark.php?type=user").search('.pages:first-child li:nth-last-child(2) a').inner_text.to_i

    multi = EM::MultiRequest.new
    (1..last_page).each do |p|
      multi.add(p, EM::HttpRequest.new("#{Pixiv::ROOT_URL}/bookmark.php?type=user&rest=show&p=#{p}").get(@options))
    end

    multi.callback do
      member_ids = []
      multi.responses[:callback].each do |name, conn|
        doc = Nokogiri::HTML(conn.response)
        member_ids += doc.search('.userdata a').map{|e| $1 if e[:href] =~ /id=(\d+)/}
      end
      yield member_ids
    end
  end
end
