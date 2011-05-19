MyApp::Application.routes.draw do
  resource :subscription
  resource :transaction do
    match 'confirm' => 'transactions#confirm'
    match 'abort' => 'transactions#abort'
  end
end
