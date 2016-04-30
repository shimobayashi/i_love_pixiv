# -*- encoding: utf-8 -*-

#XXX 本家にコミットしたい
module Pixiv
  class Client
    # Log in to Pixiv
    # @param [String] pixiv_id
    # @param [String] password
    def login(pixiv_id, password)
      doc = agent.get("#{ROOT_URL}/index.php")
      return if doc && doc.body =~ /logout/
      form = doc.forms_with(action: 'https://www.pixiv.net/login.php').first
      puts doc.body and raise Error::LoginFailed, 'login form is not available' unless form
      form.pixiv_id = pixiv_id
      form.pass = password
      doc = agent.submit(form)
      raise Error::LoginFailed unless doc && doc.body =~ /logout/
      @member_id = member_id_from_mypage(doc)
    end
  end

  class Illust
    lazy_attr_reader(:illust_id) { at!('textarea.ui-select-all').text[/illust_id=(\d+)/, 1].to_i }
    lazy_attr_reader(:member_id) {
      at!('a.user-link')[:href][/id=(\d+)/, 1].to_i
    }
    lazy_attr_reader(:member_name) {
      at!('title').inner_text[%r!「#{Regexp.escape(title)}」/「(.+)」の(?:イラスト|漫画) \[pixiv\]!, 1]
    }
    lazy_attr_reader(:small_image_url) { at!('img.bookmark_modal_thumbnail')['data-src'] }
  end
end
