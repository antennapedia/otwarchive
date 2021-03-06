class StatsController < ApplicationController

  before_filter :users_only
  before_filter :load_user
  before_filter :check_ownership

  # only the current user
  def load_user
    @user = current_user
    @check_ownership_of = @user
  end

  # gather statistics for the user on all their works
  def index
    user_works = Work.joins(:pseuds => :user).where("users.id = ?", @user.id)
    work_query = user_works.joins(:taggings).
      joins("inner join tags on taggings.tagger_id = tags.id AND tags.type = 'Fandom'").
      select("distinct tags.name as fandom, 
              works.id as id, 
              works.title as title, 
              works.revised_at as date,
              works.word_count as word_count")

    # sort 
    
    # NOTE: Because we are going to be eval'ing the @sort variable later we MUST make sure that its content is 
    # checked against the whitelist of valid options
    sort_options = %w(hits date kudos.count comments.count bookmarks.count subscriptions.count word_count)
    @sort = sort_options.include?(params[:sort_column]) ? params[:sort_column] : "hits"
    @dir = params[:sort_direction] == "ASC" ? "ASC" : "DESC"
    params[:sort_column] = @sort
    params[:sort_direction] = @dir

    # gather works and sort by specified count
    @years = ["All Years"] + user_works.value_of(:revised_at).map {|date| date.year.to_s}.uniq.sort
    @current_year = @years.include?(params[:year]) ? params[:year] : "All Years"
    if @current_year != "All Years"
      start_date = DateTime.parse("01/01/#{@current_year}")
      end_date = DateTime.parse("31/12/#{@current_year}")
      work_query = work_query.where("works.revised_at >= ? AND works.revised_at <= ?", start_date, end_date)
    end
    # NOTE: eval is used here instead of send only because you can't send "bookmarks.count" -- avoid eval
    # wherever possible and be extremely cautious of its security implications (we whitelist the contents of
    # @sort above, so this should never contain potentially dangerous user input)
    works = work_query.all.sort_by {|w| @dir == "ASC" ? (eval("w.#{@sort}") || 0) : (0-(eval("w.#{@sort}") || 0))}    

    # group by fandom or flat view
    if params[:flat_view]
      @works = {ts("All Fandoms") => works}
    else
      @works = works.group_by(&:fandom)
    end
    
    # gather totals for all works
    @totals = {}
    (sort_options - ["date"]).each do |value|
      # see explanation above about the eval here
      # the inject is used to collect the sum in the "result" variable as we iterate over all the works
      @totals[value.split(".")[0].to_sym] = works.inject(0) {|result, work| result + (eval("work.#{value}") || 0)} # sum the works
    end
    @totals[:author_subscriptions] = Subscription.where(:subscribable_id => @user.id, :subscribable_type => 'User').count

    # graph top 5 works
    @chart_data = GoogleVisualr::DataTable.new    
    @chart_data.new_column('string', 'Title')
    chart_col = @sort == "date" ? "hits" : @sort 
    chart_col_title = chart_col.split(".")[0].titleize
    chart_title = @sort == "date" ? ts("Most Recent") : ts("Top Five By #{chart_col_title}")
    @chart_data.new_column('number', chart_col_title)
      
    # Add Rows and Values 
    # see explanation above about the eval here
    @chart_data.add_rows(works[0..4].map {|w| [w.title, eval("w.#{chart_col}")]})

    # image version of bar chart
    # opts from here: http://code.google.com/apis/chart/image/docs/gallery/bar_charts.html
    @image_chart = GoogleVisualr::Image::BarChart.new(@chart_data, {:isVertical => true}).uri({
     :chtt => chart_title,
     :chs => "800x350",
     :chbh => "a",
     :chxt => "x",
     :chm => "N,000000,0,-1,11"
    })

    @chart = GoogleVisualr::Interactive::ColumnChart.new(@chart_data, :title => chart_title)
    
  end

end
