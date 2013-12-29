require 'pit'
require 'pixiv'
require 'eventmachine'

require_relative 'simple_illust_ids_fetcher'
require_relative 'famous_illust_ids_fetcher'

config = Pit.get('pixiv.net', :require => {
  id: 'your username',
  password: 'your password',
  favorite_tags: [{query: 'hoge', bookmark_threshold: 8}],
})
pixiv = Pixiv.client(config[:id], config[:password]) {|agent|
  agent.user_agent_alias = 'Mac Safari'
}
options = {head: {cookie: pixiv.agent.cookie_jar.to_a}}

EM.run do
  multi = EM::MultiRequest.new

  multi.add :simple_illust_ids_fetcher, SimpleIllustIdsFetcher.new(config, pixiv, options).fetch
  multi.add :famous_illust_ids_fetcher, FamousIllustIdsFetcher.new(config, pixiv, options).fetch

  multi.callback do
    p multi.responses[:callback].values.map{|e| e.illust_ids}.flatten

    EM.stop
  end
end
