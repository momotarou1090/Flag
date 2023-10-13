class TweetsController < ApplicationController
  before_action :authenticate_user!, only: [:new, :create]
  # CSRF対策のためのコード
  protect_from_forgery

  def index
    @tweets = Tweet.all.order("created_at DESC")
  end
  
  def new
    @tweet = Tweet.new
  end
  
  def create
    original_content = tweet_params[:content]
  
    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
  
    # 1. 適切な文章か否かの判断
    appropriateness_response = client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [
          { role: "system", content: "あなたは適切な文章を判断するAIです。文章が適切なら「適切」、不適切(暴力的、センシティブ、アダルトな内容)なら「言い換え」を出力してください。" },
          { role: "user", content: "この文章は適切ですか？: #{original_content}" }
        ]
      }
    )
  
    is_appropriate = appropriateness_response.dig("choices", 0, "message", "content").include?("適切")
  
    # 2. 1で適切と判断された文章をそのまま出力
    if is_appropriate
      final_content = original_content
    else
      # 3. 1で不適切と判断された文章を別の文章に言い換える
      revised_response = client.chat(
        parameters: {
          model: "gpt-3.5-turbo",
          messages: [
            { role: "system", content: "返事は決してしないでください。同じ意味のポジティブな言葉に言い換えてください。" },
            { role: "user", content: "#{original_content}" }
          ]
        }
      )
    
      # 3.1. 保険として再度言い換える処理
      secondary_revised_response = client.chat(
        parameters: {
          model: "gpt-3.5-turbo",
          messages: [
            { role: "system", content: "文章を10文字程度にしてください。" },
            { role: "user", content: revised_response.dig("choices", 0, "message", "content").strip }
          ]
        }
      )
    
      # 4. 3で処理した文章を出力
      final_content = secondary_revised_response.dig("choices", 0, "message", "content").strip
    end
  
    @tweet = current_user.tweets.build(content: final_content)
  
    if @tweet.save
      respond_to do |format|
        format.html { redirect_to tweets_path, notice: 'Tweet was successfully created.' }
        format.js
      end
    else
      render :new
    end
  end
  
  
  private
  
  def tweet_params
    params.require(:tweet).permit(:content, :image)
  end  
end
