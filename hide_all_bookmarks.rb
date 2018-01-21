require 'pit'
require 'pixiv'

require_relative 'pixiv_gem_monkey_patch'

class HideAllBookmarks
  def initialize
    @config = Pit.get('pixiv.net', :require => {
      id: 'your_id',
      password: 'your_password',
    })
    @pixiv = Pixiv.client(@config[:id], @config[:password]) {|agent|
      agent.user_agent_alias = 'Mac Safari'
    }
  end

  def run
    hide_all_illust_bookmarks
    hide_all_user_bookmarks
  end

  def hide_all_illust_bookmarks
    puts 'hide_all_illust_bookmarks'
    while true do
      page = @pixiv.agent.get(@pixiv.bookmark_list.url)

      form = page.form_with(action: 'bookmark_setting.php')
      checkboxes = form.checkboxes_with(name: 'book_id[]')
      button = form.button_with(name: 'hide')

      puts "checkboxes.size: #{checkboxes.size}"
      break if checkboxes.size == 0

      checkboxes.each{|cb| cb.check}
      @pixiv.agent.submit(form, button)

      puts "code: #{@pixiv.agent.page.code}"
      sleep 1
    end
  end

  def hide_all_user_bookmarks
    puts 'hide_all_user_bookmarks'
    while true do
      url = 'https://www.pixiv.net/bookmark.php?type=user'
      page = @pixiv.agent.get(url)

      form = page.form_with(action: 'bookmark_setting.php')
      checkboxes = form.checkboxes_with(name: 'id[]')
      button = form.button_with(name: 'hide')

      puts "checkboxes.size: #{checkboxes.size}"
      break if checkboxes.size == 0

      checkboxes.each{|cb| cb.check}
      @pixiv.agent.submit(form, button)

      puts "code: #{@pixiv.agent.page.code}"
      sleep 1
    end
  end
end

HideAllBookmarks.new.run
