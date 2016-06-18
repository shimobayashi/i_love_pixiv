cd `dirname $0`
bundle exec ruby newnym_poller.rb&
timeout 1h torsocks bundle exec ruby i_love_pixiv.rb SimpleIllustIdsFetcher
echo $?
timeout 1h torsocks bundle exec ruby i_love_pixiv.rb FamousIllustIdsFetcher
echo $?
timeout 1h torsocks bundle exec ruby i_love_pixiv.rb RecommendedIllustIdsFetcher
echo $?
timeout 1h torsocks bundle exec ruby i_love_pixiv.rb FamousInBookmarksIllustIdsFetcher
echo $?
timeout 1h torsocks bundle exec ruby i_love_pixiv.rb SmartSearchIllustIdsFetcher
echo $?
timeout 1h torsocks bundle exec ruby i_love_pixiv.rb InterestInBookmarkedAuthor
echo $?
kill %1
