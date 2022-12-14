# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для модели Игры
# В идеале - все методы должны быть покрыты тестами,
# в этом классе содержится ключевая логика игры и значит работы сайта.
RSpec.describe Game, type: :model do
  # пользователь для создания игр
  let(:user) { FactoryGirl.create(:user) }

  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryGirl.create(:game_with_questions, user: user) }

  # Группа тестов на работу фабрики создания новых игр
  context 'Game Factory' do
    it 'Game.create_game! new correct game' do
      # генерим 60 вопросов с 4х запасом по полю level,
      # чтобы проверить работу RANDOM при создании игры
      generate_questions(60)

      game = nil
      # создaли игру, обернули в блок, на который накладываем проверки
      expect {
        game = Game.create_game_for_user!(user)
      }.to change(Game, :count).by(1).and(# проверка: Game.count изменился на 1 (создали в базе 1 игру)
        change(GameQuestion, :count).by(15).and(# GameQuestion.count +15
          change(Question, :count).by(0) # Game.count не должен измениться
        )
      )
      # проверяем статус и поля
      expect(game.user).to eq(user)
      expect(game.status).to eq(:in_progress)
      # проверяем корректность массива игровых вопросов
      expect(game.game_questions.size).to eq(15)
      expect(game.game_questions.map(&:level)).to eq (0..14).to_a
    end
  end

  # тесты на основную игровую логику
  context 'game mechanics' do

    # правильный ответ должен продолжать игру
    it 'answer correct continues game' do
      # текущий уровень игры и статус
      level = game_w_questions.current_level
      q = game_w_questions.current_game_question
      expect(game_w_questions.status).to eq(:in_progress)

      game_w_questions.answer_current_question!(q.correct_answer_key)

      # перешли на след. уровень
      expect(game_w_questions.current_level).to eq(level + 1)
      # ранее текущий вопрос стал предыдущим
      expect(game_w_questions.previous_game_question).to eq(q)
      expect(game_w_questions.current_game_question).not_to eq(q)
      # игра продолжается
      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be_falsey
    end

    it 'take_money! finishes the game' do
      # берем игру и отвечаем на текущий вопрос
      q = game_w_questions.current_game_question
      game_w_questions.answer_current_question!(q.correct_answer_key)

      # взяли деньги
      game_w_questions.take_money!

      prize = game_w_questions.prize
      expect(prize).to be > 0

      # проверяем что закончилась игра и пришли деньги игроку
      expect(game_w_questions.status).to eq :money
      expect(game_w_questions.finished?).to be_truthy
      expect(user.balance).to eq prize
    end

    it 'current_game_question' do
      expect(game_w_questions.current_game_question) == game_w_questions.current_game_question.level - 1
    end
  end

  # группа тестов на проверку статуса игры
  context '.status' do
    # перед каждым тестом "завершаем игру"
    before do
      game_w_questions.finished_at = Time.now
      expect(game_w_questions.finished?).to be_truthy
    end

    it ':won' do
      game_w_questions.current_level = Question::QUESTION_LEVELS.max + 1
      expect(game_w_questions.status).to eq(:won)
    end

    it ':fail' do
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to eq(:fail)
    end

    it ':timeout' do
      game_w_questions.created_at = 1.hour.ago
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to eq(:timeout)
    end

    it ':money' do
      expect(game_w_questions.status).to eq(:money)
    end
  end

  describe '#current_game_question' do
    let(:level) { rand(0..Question::QUESTION_LEVELS.last) }
    before { game_w_questions.current_level = level }

    it 'should contain current level' do
      expect(game_w_questions.current_game_question).to eq game_w_questions.game_questions[level]
    end
  end

  describe '#previous_level' do
    it 'should contain previous level' do
      expect(game_w_questions.previous_level).to eq game_w_questions.current_level - 1
    end
  end

  describe '#answer_current_question!' do
    before { game_w_questions.answer_current_question!(answer_key) }

    context 'when answer is correct' do
      let!(:level) { rand(0..Game::FIREPROOF_LEVELS.last - 1) }
      let!(:answer_key) { game_w_questions.current_game_question.correct_answer_key }

      context 'question is last' do
        let!(:last_level) { Game::FIREPROOF_LEVELS.last }
        let!(:max_prize) { Game::PRIZES.last }

        before do
          game_w_questions.current_level = last_level
          game_w_questions.prize = Game::PRIZES[-2]
          game_w_questions.answer_current_question!(answer_key)
        end

        it 'assigns final prize' do
          expect(game_w_questions.prize).to eq(max_prize)
        end

        it 'finishes game with status won' do
          expect(game_w_questions.finished?).to be true
          expect(game_w_questions.status).to eq(:won)
        end
      end

      context 'question is not last' do
        before do
          game_w_questions.current_level = level
          game_w_questions.answer_current_question!(answer_key)
        end

        it 'moves to next level' do
          expect(game_w_questions.current_level).to eq(level + 1)
        end

        it 'continues game' do
          expect(game_w_questions.finished?).to be false
          expect(game_w_questions.status).to eq(:in_progress)
        end
      end

      context 'time is over' do
        before do
          game_w_questions.created_at = 1.hour.ago
          game_w_questions.time_out!
        end

        it 'finishes game with status timeout' do
          expect(game_w_questions.finished?).to be true
          expect(game_w_questions.status).to eq(:timeout)
        end
      end
    end

    context 'when answer is wrong' do
      let(:current_question) { game_w_questions.current_game_question }
      let!(:answer_key) { (current_question.variants.keys - [current_question.correct_answer_key]).first }

      it 'finishes with status fail' do
        expect(game_w_questions.finished?).to be true
        expect(game_w_questions.status).to eq(:fail)
      end
    end
  end
end
