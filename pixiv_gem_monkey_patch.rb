#XXX 本家にコミットしたい
module Pixiv
  class Illust
    lazy_attr_reader(:illust_id) { at!('link[rel="alternate"][hreflang="ja"]')[:href][/illust_id=(\d+)/, 1].to_i }
    lazy_attr_reader(:member_id) {
      at!('a.user-link')[:href][/id=(\d+)/, 1].to_i
    }
    lazy_attr_reader(:member_name) {
      at!('title').inner_text[%r!「#{Regexp.escape(title)}」/「(.+)」の(?:イラスト|漫画) \[pixiv\]!, 1]
    }
  end
end
