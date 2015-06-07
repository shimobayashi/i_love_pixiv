bundle exec ruby newnym_poller.rb&
timeout -sKILL 3600 torsocks bundle exec ruby i_love_pixiv.rb SimpleIllustIdsFetcher
echo $?
timeout -sKILL 3600 torsocks bundle exec ruby i_love_pixiv.rb FamousIllustIdsFetcher
echo $?
timeout -sKILL 3600 torsocks bundle exec ruby i_love_pixiv.rb RecommendedIllustIdsFetcher
echo $?
timeout -sKILL 3600 torsocks bundle exec ruby i_love_pixiv.rb FamousInBookmarksIllustIdsFetcher
echo $?
timeout -sKILL 3600 torsocks bundle exec ruby i_love_pixiv.rb SmartSearchIllustIdsFetcher
echo $?
kill %1
