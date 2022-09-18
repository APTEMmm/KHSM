require 'rails_helper'

RSpec.feature 'user views someone else profile', type: :feature do
  let(:profile_owner) { FactoryGirl.create(:user, name: 'Artem') }
  let(:alien_user) { FactoryGirl.create(:user, name: 'Anonymous') }

  let!(:games) do
    [
      FactoryGirl.create(:game,
                         user: profile_owner,
                         created_at: Time.parse('2022.09.19, 00:21'),
                         current_level: 5,
                         prize: 1000),

      FactoryGirl.create(:game,
                         user: profile_owner,
                         created_at: Time.parse('2022.09.09, 13:00'),
                         finished_at: Time.parse('2022.09.09, 13:05'),
                         is_failed: false,
                         prize: 1000000)
    ]
  end
  before { login_as alien_user }

  feature 'successfully' do
    before { visit '/users/1' }

    it 'shows profile owner name' do
      expect(page).to have_content 'Artem'
    end

    it 'does not show edit link' do
      expect(page).not_to have_content 'Сменить имя и пароль'
    end

    it 'shows prize' do
      expect(page).to have_content '1 000 000 ₽'
    end

    it 'shows games statuses' do
      expect(page).to have_content 'в процессе'
      expect(page).to have_content 'деньги'
    end

    it 'shows games dates' do
      expect(page).to have_content '19 сент., 00:21'
      expect(page).to have_content '09 сент., 13:00'
    end

    it 'shows number of current question' do
      expect(page).to have_content '5'
    end
  end
end
