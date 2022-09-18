require 'rails_helper'

RSpec.describe 'users/show', type: :view do

  let(:user) { FactoryGirl.create(:user, name: 'Вадим') }
  before do
    assign(:user, user)
    assign(:games, [FactoryGirl.build_stubbed(:game)])
    stub_template 'users/_game.html.erb' => 'User game goes here'
  end

  context 'same user' do
    before do
      sign_in user
      render
    end

    it 'displays game' do
      expect(rendered).to match 'User game goes here'
    end

    it 'displays name' do
      expect(rendered).to match('Вадим')
    end

    it 'displays edit link' do
      expect(rendered).to match('Сменить имя и пароль')
    end
  end

  context 'another user' do
    let(:user2) { FactoryGirl.create(:user, name: 'Миша') }
    before do
      sign_in user2
      render
    end

    it 'displays game' do
      expect(rendered).to match 'User game goes here'
    end

    it 'displays name' do
      expect(rendered).to match('Вадим')
    end

    it 'does not display alien name' do
      expect(rendered).not_to match('Миша')
    end

    it 'does not display edit link' do
      expect(rendered).not_to match('Сменить имя и пароль')
    end
  end
end
