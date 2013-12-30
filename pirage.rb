require 'net/http'
require 'uri'
require 'kconv'

# This is temporary shit
#
class Pirage
  def self.post(artist, title, url, tags, filename, image_file)
    sleep(1)
    uri = URI.parse('http://pirage.herokuapp.com/images')
    res = nil
    Net::HTTP.start(uri.host, uri.port) do |http|
      req = Net::HTTP::Post.new(uri.path)
      req['user-agent'] = 'libpirage'
      req.set_content_type('multipart/form-data; boundary=myboundary')

      body = ''
      body.concat("--myboundary\r\n")
      body.concat("content-disposition: form-data; name=\"image[artist]\"\r\n")
      body.concat("\r\n")
      body.concat("#{Kconv.toutf8(artist)}\r\n")

      body.concat("--myboundary\r\n")
      body.concat("content-disposition: form-data; name=\"image[title]\"\r\n")
      body.concat("\r\n")
      body.concat("#{Kconv.toutf8(title)}\r\n")

      body.concat("--myboundary\r\n")
      body.concat("content-disposition: form-data; name=\"image[url]\"\r\n")
      body.concat("\r\n")
      body.concat("#{Kconv.toutf8(url)}\r\n")

      body.concat("--myboundary\r\n")
      body.concat("content-disposition: form-data; name=\"image[tags]\"\r\n")
      body.concat("\r\n")
      body.concat("#{Kconv.toutf8(tags.join(' '))}\r\n")

      body.concat("--myboundary\r\n")
      body.concat("content-disposition: form-data; name=\"image[image]\"; filename=\"#{Kconv.toutf8(title)}\"\r\n")
      body.concat("\r\n")
      body.concat("#{image_file}\r\n")

      body.concat("--myboundary--\r\n")
      req.body = body

      begin
        res = http.request(req)
      rescue => exc
        print exc
        res = nil
      end
    end

    return res
  end
end
