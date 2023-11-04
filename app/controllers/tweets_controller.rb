class TweetsController < ApplicationController
  before_action :authenticate_user!, only: [:new, :create]
  # CSRF対策のためのコード
  protect_from_forgery

  def index
    @tweets = Tweet.includes(:user, image_attachment: :blob).order("created_at DESC").page(params[:page]).per(20)
    @tweet = Tweet.new
  end  
  
  def new
    @tweet = Tweet.new
  end

  def destroy
    @tweet = Tweet.find(params[:id])
    @tweet.destroy
    redirect_to tweets_url, notice: 'ツイートが削除されました'
  end
  
  def create
    original_content = tweet_params[:content]
  
    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
  
    # GPT-4に、評価と天使的な言い換えの両方を指示するプロンプトを提供
    response = client.chat(
      parameters: {
        model: "gpt-4",
        messages: [
          { 
            role: "system", 
            content: generate_combined_system_message
          },
          { role: "user", content: original_content }
        ]
      }
    )
  
    # GPT-4の応答から評価と言い換えを解析
    response_content = response.dig("choices", 0, "message", "content").strip
    begin
      response_json = JSON.parse(response_content)
  
      # 'rating' と 'paraphrase_text' のキーが存在することを確認
      if response_json.key?("rating") && response_json.key?("paraphrase_text")
        rating = response_json["rating"]
        paraphrased_content = response_json["paraphrase_text"]
      else
        # 必要なキーが見つからない場合、エラー処理
        raise "Expected fields are missing in the response"
      end
    rescue JSON::ParserError, RuntimeError => e
      # JSON解析エラーやランタイムエラーが発生した場合、エラー処理
      Rails.logger.error "Failed to process GPT-4 response: #{e.message}"
      paraphrased_content = original_content
    end
  
    # 最終的な内容でツイートを作成
    @tweet = current_user.tweets.build(content: paraphrased_content)
    
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
  def generate_combined_system_message
    <<~SYSTEM_MESSAGE
    あなたは喋れません。以下の情報をjson形式で返してください。
    1. 与えられた文章の「negative word」と「sexual word」の評価（1-10の範囲で）
    2. 与えられた文章を天使のように言い換えた内容
    例: {
      "rating": {
        "negative word": 5,
        "sexual word": 2
      },
      "paraphrase_text": "天使的な言い換え内容"
    }
    SYSTEM_MESSAGE
  end
  

  def tweet_params
    params.require(:tweet).permit(:content, :image)
  end  
end
