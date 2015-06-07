bundle exec ruby newnym_poller.rb&
timeout -sKILL 3600 torsocks bundle exec ruby i_love_pixiv.rb
echo $?
kill %1
