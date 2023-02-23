# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'date'

class MembersController < ApplicationController
  model_object Member
  before_action :find_model_object, :except => [:index, :new, :create, :autocomplete]
  before_action :find_project_from_association, :except => [:index, :new, :create, :autocomplete]
  before_action :find_project_by_project_id, :only => [:index, :new, :create, :autocomplete]
  before_action :authorize
  accept_api_auth :index, :show, :create, :update, :destroy

  require_sudo_mode :create, :update, :destroy

  include ApplicationHelper

  def index
    scope = @project.memberships
    @offset, @limit = api_offset_and_limit
    @member_count = scope.count
    @member_pages = Paginator.new @member_count, @limit, params['page']
    @offset ||= @member_pages.offset
    @members = scope.includes(:principal, :roles).order(:id).limit(@limit).offset(@offset).to_a

    respond_to do |format|
      format.html {head 406}
      format.api
    end
  end

  def show
    respond_to do |format|
      format.html {head 406}
      format.api
    end
  end

  def new
    @member = Member.new
  end

  def create
    members = []
    if params[:membership]
      user_ids = Array.wrap(params[:membership][:user_id] || params[:membership][:user_ids])
      user_ids << nil if user_ids.empty?
      user_ids.each do |user_id|
        member = Member.new(:project => @project, :user_id => user_id)
        member.set_editable_role_ids(params[:membership][:role_ids])

        members << member
      end
      @project.members << members
    end

    latest_member = members.last
    data = {
      member_id: latest_member.user.id,
      member_name: latest_member.user.name,
      member_phone: latest_member.user.custom_value_for(CustomField.find_by(name: 'Phone Number').id).value,
      project_name: latest_member.project.name,
      sender_name: User.current.name
    }

    member_id = data[:member_id]
    member_name = data[:member_name]
    member_phone_number = data[:member_phone]
    sender_name = data[:sender_name]
    project_name = data[:project_name]

    hariIni = helper_method

    ApplicationHelper.log_project_publish_to_rabbitmq(member_id, member_name, member_phone_number, { status: 200, message: "#{sender_name} menambahkan #{member_name} pada project #{project_name} pada hari #{hariIni}, tanggal #{Date.today.strftime("%d %B %Y")}, Jam #{Time.now.strftime("%H:%M")}" })

    # hariIni = helper_method

    # ApplicationHelper.log_project_publish_to_rabbitmq(User.current.id, members.name, '085695951121', { status: 200, message: "#{User.current.name} membuat project #{@project.name} pada hari #{hariIni}, tanggal #{Date.today.strftime("%d %B %Y")}, Jam #{Time.now.strftime("%H:%M")}" })

    respond_to do |format|
      format.html {redirect_to_settings_in_projects}
      format.js do
        @members = members
        @member = Member.new
      end
      format.api do
        @member = members.first
        if @member.valid?
          render :action => 'show', :status => :created, :location => membership_url(@member)
        else
          render_validation_errors(@member)
        end
      end
    end
  end

  def edit
    @roles = Role.givable.to_a
  end

  def update
    if params[:membership]
      @member.set_editable_role_ids(params[:membership][:role_ids])
    end
    saved = @member.save
    respond_to do |format|
      format.html {redirect_to_settings_in_projects}
      format.js
      format.api do
        if saved
          render_api_ok
        else
          render_validation_errors(@member)
        end
      end
    end
  end

  def destroy
    if @member.deletable?
      @member.destroy
    end
    respond_to do |format|
      format.html {redirect_to_settings_in_projects}
      format.js
      format.api do
        if @member.destroyed?
          render_api_ok
        else
          head :unprocessable_entity
        end
      end
    end
  end

  def autocomplete
    respond_to do |format|
      format.js
    end
  end

  private

  def redirect_to_settings_in_projects
    redirect_to settings_project_path(@project, :tab => 'members')
  end
end
