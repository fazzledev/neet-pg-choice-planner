class CreateOauthClientsAndGrants < ActiveRecord::Migration[8.1]
  def change
    create_table :oauth_clients do |t|
      t.string :client_id, null: false, index: { unique: true }
      t.string :client_name, null: false
      t.json :redirect_uris, null: false, default: []
      t.timestamps
    end

    create_table :oauth_grants do |t|
      t.references :oauth_client, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :session, null: false, foreign_key: true, index: { unique: true }
      t.string :redirect_uri, null: false
      t.string :scope, null: false
      t.string :resource
      t.string :code_digest, null: false, index: { unique: true }
      t.string :code_challenge, null: false
      t.datetime :code_expires_at, null: false
      t.datetime :code_used_at
      t.string :access_token_digest, index: { unique: true }
      t.datetime :access_expires_at
      t.string :refresh_token_digest, index: { unique: true }
      t.datetime :refresh_expires_at
      t.datetime :last_used_at
      t.timestamps
    end
  end
end
