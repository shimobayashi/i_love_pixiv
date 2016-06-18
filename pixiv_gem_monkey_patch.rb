# -*- encoding: utf-8 -*-

module Pixiv
  class Client
    # Log in to Pixiv
    # @param [String] pixiv_id
    # @param [String] password
    def login(pixiv_id, password)
      doc = agent.get("#{ROOT_URL}/index.php")
      return if doc && doc.body =~ /logout/
      doc = agent.get( "https://accounts.pixiv.net/login" )
      form = doc.forms_with(action: "/login").first
      raise Error::LoginFailed, 'login form is not available' unless form
      form.pixiv_id = pixiv_id
      form.password = password
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
    lazy_attr_reader(:caption) { # 本家からのコピペ。めんどくて追従させてないのでひどい
       node = doc.at('.work-info .caption')
       if node
         node.inner_text
       else
         ""
       end
     }
  end

  class OwnedIllustList < IllustList
    # @return [Integer]
    lazy_attr_reader(:member_id) {
      doc.body[/pixiv\.context\.userId = "(\d+)"/, 1].to_i
    }
  end
end
