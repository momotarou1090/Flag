class UsersController < ApplicationController
  def follow
    user = User.find(params[:id])
    current_user.follow(user)
    redirect_to user_path(user)
  end
  
  def unfollow
    user = User.find(params[:id])
    current_user.unfollow(user)
    redirect_to user_path(user)
  end
  
  def show
    @user = User.find(params[:id])
    @tweets = Tweet.includes(:user, image_attachment: :blob).order("created_at DESC").page(params[:page]).per(20)
  end
  
  def following
    @user = User.find(params[:id])
    @users = @user.following
    render 'show_follow'
  end

  def followers
    @user = User.find(params[:id])
    @users = @user.followers
    render 'show_follow'
  end
end
