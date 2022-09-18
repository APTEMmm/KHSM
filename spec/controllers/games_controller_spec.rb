require 'rails_helper'
require 'support/my_spec_helper'

RSpec.describe GamesController, type: :controller do
  # обычный пользователь
  let(:user) { FactoryGirl.create(:user) }
  # админ
  let(:admin) { FactoryGirl.create(:user, is_admin: true) }
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryGirl.create(:game_with_questions, user: user) }

  let(:game) { assigns(:game) }

  describe '#show' do
    context 'when anonymous' do
      before { get :show, id: game_w_questions.id }

      it 'returns no positive response' do
        expect(response.status).not_to eq(200)
      end

      it 'redirects to login' do
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'returns alert flash' do
        expect(flash[:alert]).to be
      end
    end

    context 'when registered user' do
      before { sign_in user }

      context 'tries to watch own game' do
        it 'shows game' do
          get :show, id: game_w_questions.id

          expect(game.finished?).to be false
          expect(game.user).to eq(user)

          expect(response.status).to eq(200) # должен быть ответ HTTP 200
          expect(response).to render_template('show') # и отрендерить шаблон show
        end
      end

      context 'tries to watch someone else game' do
        let(:alien_game) { FactoryGirl.create(:game_with_questions) }
        it 'does not show alien game' do

          get :show, id: alien_game.id

          expect(response.status).not_to eq(200) # статус не 200 ОК
          expect(response).to redirect_to(root_path)
          expect(flash[:alert]).to be # во flash должен быть прописана ошибка
        end
      end
    end
  end

  describe '#create' do
    context 'when anonymous' do
      before { post :create, id: game_w_questions.id }

      it 'returns no positive response' do
        expect(response.status).not_to eq(200)
      end

      it 'redirects to login' do
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'returns alert flash' do
        expect(flash[:alert]).to be
      end
    end

    context 'when registered user' do
      before { sign_in user }

      context 'tries to create first game' do
        it 'creates game' do
          # сперва накидаем вопросов, из чего собирать новую игру
          generate_questions(15)

          post :create

          # проверяем состояние этой игры
          expect(game.finished?).to be false
          expect(game.user).to eq(user)
          # и редирект на страницу этой игры
          expect(response).to redirect_to(game_path(game))
          expect(flash[:notice]).to be
        end
      end

      context 'tries to create second game' do
        it 'creates game' do
          # убедились что есть игра в работе
          expect(game_w_questions.finished?).to be false

          # отправляем запрос на создание, убеждаемся что новых Game не создалось
          expect { post :create }.to change(Game, :count).by(0)

          expect(game).to be_nil

          # и редирект на страницу старой игры
          expect(response).to redirect_to(game_path(game_w_questions))
          expect(flash[:alert]).to be
        end
      end
    end
  end

  describe '#answer' do
    context 'when anonymous' do
      before { put :answer, id: game_w_questions.id }

      it 'returns no positive response' do
        expect(response.status).not_to eq(200)
      end

      it 'redirects to login' do
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'returns alert flash' do
        expect(flash[:alert]).to be
      end
    end

    context 'when registered user' do
      before { sign_in user }

      context 'answers correct' do
        # передаем параметр params[:letter]
        before { put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key }

        it 'continues the game' do
          expect(game.finished?).to be false
          expect(game.current_level).to be > 0
          expect(response).to redirect_to(game_path(game))
          expect(flash.empty?).to be true # удачный ответ не заполняет flash
        end
      end

      context 'gives wrong answer' do
        let(:current_question) { game_w_questions.current_game_question }
        let(:incorrect_answer_key) { (current_question.variants.keys - [current_question.correct_answer_key]).first }
        let(:prize) { game_w_questions.prize }

        before { put :answer, id: game_w_questions.id, letter: incorrect_answer_key }

        it 'ends the game' do
          expect(game.finished?).to be(true)
        end

        it 'returns alert flash' do
          expect(flash[:alert]).to be
        end

        it 'accrues fire proof prize' do
          expect(user.balance).to eq prize
        end
      end
    end
  end

  describe '#take_money' do
    context 'when anonymous' do
      before { put :take_money, id: game_w_questions.id }

      it 'returns no positive response' do
        expect(response.status).not_to eq(200)
      end

      it 'redirects to login' do
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'returns alert flash' do
        expect(flash[:alert]).to be
      end
    end

    context 'when registered user' do
      before do
        sign_in user
        game_w_questions.update_attribute(:current_level, 2)
        put :take_money, id: game_w_questions.id
      end
      context 'tries to take money' do
        it 'finishes the game with prize' do
          expect(game.finished?).to be true

          expect(game.prize).to eq(200)
          user.reload
          expect(user.balance).to eq(200)

          expect(response).to redirect_to(user_path(user))
          expect(flash[:warning]).to be
        end
      end
    end
  end

  describe '#help' do
    context 'when anonymous' do
      before { put :help, id: game_w_questions.id }

      it 'returns no positive response' do
        expect(response.status).not_to eq(200)
      end

      it 'redirects to login' do
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'returns alert flash' do
        expect(flash[:alert]).to be
      end
    end

    context 'when registered user' do
      before { sign_in user }

      context 'uses audience help' do
        context 'before use' do
          it 'does not have this hint' do
            expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
            expect(game_w_questions.audience_help_used).to be false
          end
        end
        context 'after use' do
          before { put :help, id: game_w_questions.id, help_type: :audience_help }

          it 'does not end the game' do
            expect(game.finished?).to be false
          end

          it 'uses hint' do
            expect(game.audience_help_used).to be true
          end

          it 'uses hint correctly' do
            expect(game.current_game_question.help_hash[:audience_help]).to be
            expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
          end

          it 'redirects to game' do
            expect(response).to redirect_to(game_path(game))
          end
        end
      end

      context 'uses fifty_fifty hint' do
        context 'before use' do
          it 'does not have this hint' do
            expect(game_w_questions.current_game_question.help_hash[:fifty_fifty]).not_to be
            expect(game_w_questions.fifty_fifty_used).to be false
          end
        end
        context 'after use' do
          before { put :help, id: game_w_questions.id, help_type: :fifty_fifty }

          it 'does not end the game' do
            expect(game.finished?).to be false
          end

          it 'uses hint' do
            expect(game.fifty_fifty_used).to be true
          end

          it 'uses hint correctly' do
            expect(game.current_game_question.help_hash[:fifty_fifty]).to be
            expect(game.current_game_question.help_hash[:fifty_fifty]).to include(game.current_game_question.correct_answer_key)
            expect(game.current_game_question.help_hash[:fifty_fifty].size).to eq 2
          end
          it 'redirects to game' do
            expect(response).to redirect_to(game_path(game))
          end
        end
      end
    end
  end
end
