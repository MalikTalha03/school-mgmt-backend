require 'rails_helper'

RSpec.describe JwtDenylist, type: :model do
  describe 'factory' do
    it 'is valid' do
      expect(build(:jwt_denylist)).to be_valid
    end
  end

  describe 'configuration' do
    it 'uses jwt_denylists table' do
      expect(described_class.table_name).to eq('jwt_denylists')
    end

    it 'includes devise denylist strategy' do
      expect(described_class.included_modules).to include(Devise::JWT::RevocationStrategies::Denylist)
    end
  end
end
