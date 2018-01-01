require 'pit'
require 'pixiv'

require_relative 'pixiv_gem_monkey_patch'

config = Pit.get('pixiv.net', :require => {
  id: 'your_id',
  password: 'your_password',
})
pixiv = Pixiv.client(config[:id], config[:password]) {|agent|
  agent.user_agent_alias = 'Mac Safari'
}

followees = []
num = 0
while true
  num += 1
  url = "https://www.pixiv.net/bookmark.php?type=user&rest=hide&p=#{num}"
  page = pixiv.agent.get(url)
  hrefs = page.parser.search('div.userdata a').map{|e| e.attr('href')}
  break if hrefs.size == 0
  followees.concat(hrefs)
  sleep 0.1
end

followees.each {|followee|
  url = "https://www.pixiv.net/#{followee}"
  page = pixiv.agent.get(url)
  href = page.parser.search('.badges a').map{|e| e.attr('href')}.grep(/pawoo/){|href| href}[0]
  puts href if href
  sleep 0.1
}
