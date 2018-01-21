cd `dirname $0`
timeout 1h bundle exec ruby hide_all_bookmarks.rb
echo $?
timeout 1h bundle exec ruby i_love_pixiv.rb SimpleIllustIdsFetcher
echo $?
timeout 1h bundle exec ruby i_love_pixiv.rb FamousIllustIdsFetcher
echo $?
timeout 1h bundle exec ruby i_love_pixiv.rb RecommendedIllustIdsFetcher
echo $?
timeout 1h bundle exec ruby i_love_pixiv.rb FamousInBookmarksIllustIdsFetcher
echo $?
timeout 1h bundle exec ruby i_love_pixiv.rb SmartSearchIllustIdsFetcher
echo $?
timeout 1h bundle exec ruby i_love_pixiv.rb InterestInBookmarkedAuthor
echo $?
kill %1
