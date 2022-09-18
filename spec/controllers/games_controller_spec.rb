# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для игрового контроллера
# Самые важные здесь тесты:
#   1. на авторизацию (чтобы к чужим юзерам не утекли не их данные)
#   2. на четкое выполнение самых важных сценариев (требований) приложения
#   3. на передачу граничных/неправильных данных в попытке сломать контроллер
#
RSpec.describe GamesController, type: :controller do
  # обычный пользователь
  let(:user) { FactoryGirl.create(:user) }
  # админ
  let(:admin) { FactoryGirl.create(:user, is_admin: true) }
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryGirl.create(:game_with_questions, user: user) }

  # группа тестов для незалогиненного юзера (Анонимус)
  context 'Anon' do
    describe '#show' do
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

    describe '#create' do
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

    describe '#answer' do
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

    describe '#take_money' do
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

    describe '#help' do
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
  end

  # группа тестов на экшены контроллера, доступных залогиненным юзерам
  context 'Usual user' do
    # перед каждым тестом в группе
    before(:each) { sign_in user } # логиним юзера user с помощью спец. Devise метода sign_in

    # юзер может создать новую игру
    it 'creates game' do
      # сперва накидаем вопросов, из чего собирать новую игру
      generate_questions(15)

      post :create
      game = assigns(:game) # вытаскиваем из контроллера поле @game

      # проверяем состояние этой игры
      expect(game.finished?).to be_falsey
      expect(game.user).to eq(user)
      # и редирект на страницу этой игры
      expect(response).to redirect_to(game_path(game))
      expect(flash[:notice]).to be
    end

    # юзер видит свою игру
    it '#show game' do
      get :show, id: game_w_questions.id
      game = assigns(:game) # вытаскиваем из контроллера поле @game
      expect(game.finished?).to be_falsey
      expect(game.user).to eq(user)

      expect(response.status).to eq(200) # должен быть ответ HTTP 200
      expect(response).to render_template('show') # и отрендерить шаблон show
    end

    # юзер отвечает на игру корректно - игра продолжается
    it 'answers correct' do
      # передаем параметр params[:letter]
      put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
      game = assigns(:game)

      expect(game.finished?).to be_falsey
      expect(game.current_level).to be > 0
      expect(response).to redirect_to(game_path(game))
      expect(flash.empty?).to be_truthy # удачный ответ не заполняет flash
    end

    # юзер отвечает на вопрос неправильно - игра заканчивается
    context 'user gives wrong answer' do
      let(:current_question) { game_w_questions.current_game_question }
      let(:incorrect_answer_key) { (current_question.variants.keys - [current_question.correct_answer_key]).first }
      let(:game) { assigns(:game) }
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

    describe '#help' do
      let(:game) { assigns(:game) }

      context 'uses audience help' do
        context 'before use' do
          it 'does not have this hint' do
            expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
            expect(game_w_questions.audience_help_used).to be false
          end
        end
        context 'after use' do
          before { put :help, id: game_w_questions.id, help_type: :audience_help }

          it 'uses hint correctly' do
            expect(game.finished?).to be false
            expect(game.audience_help_used).to be true
            expect(game.current_game_question.help_hash[:audience_help]).to be
            expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
            expect(response).to redirect_to(game_path(game))
          end
        end
      end

      context 'uses audience help' do
        context 'before use' do
          it 'does not have this hint' do
            expect(game_w_questions.current_game_question.help_hash[:fifty_fifty]).not_to be
            expect(game_w_questions.fifty_fifty_used).to be false
          end
        end
        context 'after use' do
          before { put :help, id: game_w_questions.id, help_type: :fifty_fifty }

          it 'uses hint correctly' do
            expect(game.finished?).to be false
            expect(game.fifty_fifty_used).to be true
            expect(game.current_game_question.help_hash[:fifty_fifty]).to be
            expect(game.current_game_question.help_hash[:fifty_fifty]).to include(game.current_game_question.correct_answer_key)
            expect(game.current_game_question.help_hash[:fifty_fifty].size).to eq 2
            expect(response).to redirect_to(game_path(game))
          end
        end
      end
    end

    # проверка, что пользовтеля посылают из чужой игры
    it '#show alien game' do
      # создаем новую игру, юзер не прописан, будет создан фабрикой новый
      alien_game = FactoryGirl.create(:game_with_questions)

      # пробуем зайти на эту игру текущий залогиненным user
      get :show, id: alien_game.id

      expect(response.status).not_to eq(200) # статус не 200 ОК
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be # во flash должен быть прописана ошибка
    end

    # юзер берет деньги
    it 'takes money' do
      # вручную поднимем уровень вопроса до выигрыша 200
      game_w_questions.update_attribute(:current_level, 2)

      put :take_money, id: game_w_questions.id
      game = assigns(:game)
      expect(game.finished?).to be_truthy
      expect(game.prize).to eq(200)

      # пользователь изменился в базе, надо в коде перезагрузить!
      user.reload
      expect(user.balance).to eq(200)

      expect(response).to redirect_to(user_path(user))
      expect(flash[:warning]).to be
    end

    # юзер пытается создать новую игру, не закончив старую
    it 'try to create second game' do
      # убедились что есть игра в работе
      expect(game_w_questions.finished?).to be_falsey

      # отправляем запрос на создание, убеждаемся что новых Game не создалось
      expect { post :create }.to change(Game, :count).by(0)

      game = assigns(:game) # вытаскиваем из контроллера поле @game
      expect(game).to be_nil

      # и редирект на страницу старой игры
      expect(response).to redirect_to(game_path(game_w_questions))
      expect(flash[:alert]).to be
    end
  end
end
