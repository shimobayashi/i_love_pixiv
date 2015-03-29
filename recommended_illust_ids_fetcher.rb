require 'rubygems'
require 'eventmachine'
require 'em-http-request'
require 'pixiv'
require 'json'

require_relative 'utils'

# おすすめユーザーからイラストIDを取得する
#
class RecommendedIllustIdsFetcher < EM::DefaultDeferrable
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
    page = @pixiv.agent.get 'http://www.pixiv.net/search_user.php'
    tt = page.at('input[name="tt"]')[:value]
    sample_users = page.body[/pixiv\.context\.userRecommendSampleUser = "(.+?)"/, 1]
    page = @pixiv.agent.get 'http://www.pixiv.net/rpc/recommender.php', {
      type: 'user',
      sample_users: sample_users,
      num_recommendations: 20, # これがそのままjob数になる
      following_booster_model: 1,
      tt: tt,
    }, 'http://www.pixiv.net/search_user.php'
    json = JSON.load(page.body)
    json['user_ids'].each {|user_id|
      page = @pixiv.agent.get 'http://www.pixiv.net/rpc/get_profile.php', {
        user_ids: user_id,
        illust_num: 4,
        get_illust_count: 1,
        tt: tt,
      }, 'http://www.pixiv.net/search_user.php'
      json = JSON.load(page.body)

      illusts = json['body'][0]['illusts']
      next unless illusts && illusts[0]
      illust_id = illusts[0]['illust_id'].to_i

      @jobs[illust_id] = {name: :recommend, score_threshold: 1000}
    }

    page = @pixiv.agent.get 'http://www.pixiv.net/bookmark.php'
    tt = page.at('input[name="tt"]')[:value]
    sample_illusts = page.body[/pixiv\.context\.illustRecommendSampleIllust = "(.+?)"/, 1]
    page = @pixiv.agent.get 'http://www.pixiv.net/rpc/recommender.php', {
      type: 'illust',
      sample_illusts: sample_illusts,
      num_recommendations: 20, # これがそのままjob数になる
      tt: tt,
    }, 'http://www.pixiv.net/bookmark.php'
    json = JSON.load(page.body)
    json['recommendations'].each {|illust_id|
      @jobs[illust_id] = {name: :recommend_by_bookmark, score_threshold: 300}
    }

    succeed @jobs

    self
  end
end
