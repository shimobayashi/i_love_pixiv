# -*- encoding: utf-8 -*-

module Pixiv
  ROOT_URL = 'https://www.pixiv.net'

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

    def member_id_from_mypage(doc)
      elem = doc.at('a.user-link') || doc.at('div.ui-layout-west a._user-icon')
      raise 'elem not found!' unless elem
      elem['href'][/\d+$/].to_i
    end
  end

  class Illust
    # なんかJavaScriptのオブジェクトとしてイラストデータを取り回すようになっていて全体的にデータのとり方を変える必要がある状態で、気づいたものから置き換えている
    def _illust_str
      return doc.to_s[/\(({token:.+})\);<\/script>/, 1]
    end
    def codepointo_to_s(str)
      # https://techracho.bpsinc.jp/baba/2013_05_31/8837
      s = str.gsub(/\\u([\da-fA-F]{4})/) { [$1].pack('H*').unpack('n*').pack('U*') }
      return s.gsub('\/', '/') # スラッシュもエスケープされているようなので置換する。他にもこういう文字はあるかもしれない
    end

    lazy_attr_reader(:illust_id) {
      _illust_str[/"illustId":"(\d+)"/, 1].to_i
    }
    lazy_attr_reader(:member_id) {
      at!('a.user-link')[:href][/id=(\d+)/, 1].to_i
    }
    lazy_attr_reader(:title) {
      at!('title').inner_text[%r!「(.+)」/「(.+)」の(?:イラスト|漫画) \[pixiv\]!, 1]
    }
    lazy_attr_reader(:member_name) {
      at!('title').inner_text[%r!「(.+)」/「(.+)」の(?:イラスト|漫画) \[pixiv\]!, 2]
    }
    lazy_attr_reader(:small_image_url) {
      _illust_str[/"smaill":"(.+?)"/, 1].gsub('\/', '/')
    }
    lazy_attr_reader(:medium_image_url) {
      _illust_str[/"regular":"(.+?)"/, 1].gsub('\/', '/')
    }
    lazy_attr_reader(:caption) {
      illust_comment = _illust_str[/"illustComment":"(.+?)"/, 1]
      codepointo_to_s(illust_comment)
    }
    lazy_attr_reader(:score) {
      _illust_str[/"likeCount":(\d+)/, 1].to_i * 10
    } # レーティングからいいね！に変わった
    lazy_attr_reader(:tag_names) {
      _illust_str.scan(/"tag":"(.+?)"/).map {|match|
        codepointo_to_s(match[0])
      }
    }
  end

  class OwnedIllustList < IllustList
    # @return [Integer]
    lazy_attr_reader(:member_id) {
      doc.body[/pixiv\.context\.userId = "(\d+)"/, 1].to_i
    }
  end

  class OwnedIllustList < IllustList
    # @return [Integer]
    lazy_attr_reader(:member_id) {
      doc.body[/pixiv\.context\.userId = "(\d+)"/, 1].to_i
    }
  end
end
