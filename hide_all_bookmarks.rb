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
end

HideAllBookmarks.new.run
