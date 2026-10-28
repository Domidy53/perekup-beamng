angular.module('beamng.apps').directive('perekupApp', function () {
  return {
    restrict: 'E',
    replace: false,
    template: `
      <section class="perekup-app">
        <link type="text/css" rel="stylesheet" href="/ui/modules/apps/perekup/app.css" />
        <header class="perekup-header">
          <div>
            <div class="perekup-eyebrow">КАРЬЕРА · FREE ROAM</div>
            <h1>ПЕРЕКУП</h1>
          </div>
          <button class="perekup-icon-button" ng-click="refresh()" title="Обновить" aria-label="Обновить">↻</button>
        </header>

        <div class="perekup-continue" ng-if="snapshot.status === 'active' && !careerOpen">
          <span class="perekup-step">СОХРАНЁННАЯ КАРЬЕРА · ДЕНЬ {{snapshot.career.day}}</span>
          <h2>Продолжить дело?</h2>
          <p>Баланс &#36;{{snapshot.career.money | number:0}} · машин в гараже {{garageCount()}}</p>
          <button class="perekup-primary" ng-click="continueCareer()">Продолжить карьеру</button>
        </div>

        <div class="perekup-stats" ng-if="snapshot.status === 'active' && careerOpen">
          <div><span>Баланс</span><strong>{{snapshot.career.money | number:0}} $</strong></div>
          <div><span>День</span><strong>{{snapshot.career.day}}</strong></div>
          <div><span>В гараже</span><strong>{{garageCount()}}</strong></div>
        </div>

        <div class="perekup-message" ng-if="snapshot.message" ng-bind="snapshot.message"></div>
        <div class="perekup-warning" ng-if="snapshot.warning" ng-bind="snapshot.warning"></div>
        <div class="perekup-warning" ng-if="snapshot.catalogError" ng-bind="snapshot.catalogError"></div>

        <div class="perekup-error" ng-if="snapshot.status === 'error'">
          <h2>Сохранение недоступно</h2>
          <p>Карьера не будет перезаписана. Проверьте файл сохранения в папке settings пользовательской папки BeamNG.drive.</p>
        </div>

        <div class="perekup-new" ng-if="snapshot.status === 'new'">
          <div class="perekup-intro">
            <span class="perekup-step">НОВОЕ ДЕЛО · 01</span>
            <h2>Начните с малого</h2>
            <p>Выберите доступную машину из каталога вашей игры. Она станет первой в гараже, а на баланс будет зачислено $500.</p>
          </div>
          <div class="perekup-empty" ng-if="snapshot.starterOptions.length === 0">
            <strong>Машины не найдены</strong>
            <span>Убедитесь, что уровень East Coast USA загружен и каталог автомобилей готов.</span>
          </div>
          <article class="perekup-card perekup-starter" ng-repeat="car in snapshot.starterOptions track by car.key">
            <div class="perekup-card-title"><strong ng-bind="car.displayName"></strong><span ng-bind="car.type"></span></div>
            <div class="perekup-card-meta">Конфигурация: <span ng-bind="car.configName"></span> · ID модели: <code ng-bind="car.modelKey"></code></div>
            <button class="perekup-primary" ng-click="startCareer(car.id)">Выбрать машину</button>
          </article>
          <p class="perekup-footnote" ng-if="snapshot.starterOptions.length > 0 && snapshot.starterOptions.length < 3">
            В каталоге доступно {{snapshot.starterOptions.length}} из 3 возможных стартовых машин.
          </p>
        </div>

        <div class="perekup-active" ng-if="snapshot.status === 'active' && careerOpen">
          <nav class="perekup-tabs" aria-label="Разделы карьеры">
            <button ng-class="{selected: tab === 'overview'}" ng-click="setTab('overview')">Дело</button>
            <button ng-class="{selected: tab === 'market'}" ng-click="setTab('market')">Объявления</button>
            <button ng-class="{selected: tab === 'garage'}" ng-click="setTab('garage')">Гараж</button>
            <button ng-class="{selected: tab === 'history'}" ng-click="setTab('history')">История</button>
          </nav>

          <div class="perekup-panel" ng-if="tab === 'overview'">
            <div class="perekup-intro compact">
              <span class="perekup-step">ДЕНЬ {{snapshot.career.day}}</span>
              <h2>Ваше дело</h2>
              <p>Покупайте машины из доступного каталога, оплачивайте один базовый ремонт и выставляйте их на перепродажу.</p>
            </div>
            <div class="perekup-car-highlight" ng-if="starterCar()">
              <span>Стартовая машина</span>
              <strong ng-bind="starterCar().displayName"></strong>
              <span ng-if="starterCar().modelAvailable === false" class="perekup-missing">Конфигурация сейчас недоступна. Запись сохранена.</span>
            </div>
            <div class="perekup-row-actions">
              <button class="perekup-secondary" ng-click="setTab('market')">Открыть объявления</button>
              <button class="perekup-primary" ng-click="advanceDay()">Следующий день</button>
            </div>
            <p class="perekup-footnote">Объявления обновляются при переходе к следующему дню. Все действия и баланс сохраняются локально.</p>
          </div>

          <div class="perekup-panel" ng-if="tab === 'market'">
            <div class="perekup-section-heading"><div><span class="perekup-step">ДЕНЬ {{snapshot.career.day}}</span><h2>Объявления</h2></div><span class="perekup-count">{{snapshot.career.listings.length}}</span></div>
            <article class="perekup-card" ng-repeat="offer in snapshot.career.listings track by offer.id" ng-if="offer.status === 'available'">
              <div class="perekup-card-title"><strong ng-bind="offer.displayName"></strong><span ng-bind="offer.type"></span></div>
              <div class="perekup-price-line"><strong>{{offer.price | number:0}} $</strong><span>примерная цена</span></div>
              <div class="perekup-card-meta">Конфигурация: <span ng-bind="offer.configName"></span> · состояние: 35% · ID <code ng-bind="offer.modelKey"></code></div>
              <button class="perekup-primary" ng-click="buy(offer.id)" ng-disabled="snapshot.career.money < offer.price">Купить</button>
            </article>
            <div class="perekup-empty" ng-if="availableOffers().length === 0">
              <strong>Новых объявлений нет</strong><span>Перейдите к следующему дню или установите совместимый автомобильный мод.</span>
              <button class="perekup-secondary" ng-click="advanceDay()">Обновить день</button>
            </div>
          </div>

          <div class="perekup-panel" ng-if="tab === 'garage'">
            <div class="perekup-section-heading"><div><span class="perekup-step">СОБСТВЕННОСТЬ</span><h2>Гараж</h2></div><span class="perekup-count">{{snapshot.career.vehicles.length}}</span></div>
            <article class="perekup-card" ng-repeat="car in snapshot.career.vehicles track by car.id" ng-if="car.status !== 'sold'">
              <div class="perekup-card-title"><strong ng-bind="car.displayName"></strong><span ng-bind="statusLabel(car.status)"></span></div>
              <div class="perekup-condition"><div><span>Состояние</span><strong>{{car.condition}}%</strong></div><div class="perekup-meter"><i ng-style="{width: car.condition + '%'}"></i></div></div>
              <div class="perekup-missing" ng-if="car.modelAvailable === false">Конфигурация недоступна в текущей установке. Запись о машине сохранена.</div>
              <div class="perekup-card-meta" ng-if="car.repairCost > 0">Расходы на ремонт: {{car.repairCost | number:0}} $</div>
              <div class="perekup-card-meta" ng-if="car.status === 'for_sale'">Цена продажи: {{car.askingPrice | number:0}} $</div>
              <div class="perekup-row-actions" ng-if="car.status === 'owned'">
                <button class="perekup-secondary" ng-click="repair(car.id)" ng-disabled="car.repairUsed || car.condition >= 100 || snapshot.career.money < 75">Ремонт · 75 $</button>
                <button class="perekup-primary" ng-click="list(car.id)">Выставить</button>
              </div>
              <button class="perekup-primary" ng-if="car.status === 'for_sale'" ng-click="sell(car.id)">Продать за {{car.askingPrice | number:0}} $</button>
            </article>
            <div class="perekup-empty" ng-if="snapshot.career.vehicles.length === 0"><strong>Гараж пуст</strong></div>
          </div>

          <div class="perekup-panel" ng-if="tab === 'history'">
            <div class="perekup-section-heading"><div><span class="perekup-step">СДЕЛКИ И РЕШЕНИЯ</span><h2>История</h2></div><span class="perekup-count">{{snapshot.career.history.length}}</span></div>
            <article class="perekup-history-item" ng-repeat="entry in snapshot.career.history track by entry.id">
              <span class="perekup-history-day">День {{entry.day}}</span><strong ng-bind="entry.description"></strong>
              <span class="perekup-history-amount" ng-class="{positive: entry.amount > 0, negative: entry.amount < 0}">{{entry.amount > 0 ? '+' : ''}}{{entry.amount | number:0}} $ · баланс {{entry.balanceAfter | number:0}} $</span>
            </article>
            <div class="perekup-empty" ng-if="snapshot.career.history.length === 0"><strong>История пока пуста</strong></div>
          </div>
        </div>

        <footer class="perekup-footer">Работает локально · Без сетевых запросов · Цены примерные</footer>
      </section>
    `,
    link: function (scope) {
      var snapshotListener;
      scope.tab = 'overview';
      scope.careerOpen = false;
      scope.snapshot = { status: 'loading', starterOptions: [] };

      function safeId(value) {
        return typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
      }

      function callEngine(method, id) {
        var allowed = ['startCareer', 'buyListing', 'repairVehicle', 'listVehicle', 'sellVehicle'];
        if (allowed.indexOf(method) === -1 || !safeId(id) || !window.bngApi || typeof bngApi.engineLua !== 'function') {
          return;
        }
        bngApi.engineLua("extensions.perekup_core." + method + "('" + id + "')");
      }

      scope.refresh = function () {
        if (window.bngApi && typeof bngApi.engineLua === 'function') {
          bngApi.engineLua('extensions.perekup_core.requestSnapshot()');
        }
      };
      scope.startCareer = function (key) {
        callEngine('startCareer', key);
        scope.careerOpen = true;
      };
      scope.continueCareer = function () { scope.careerOpen = true; };
      scope.buy = function (id) { callEngine('buyListing', id); };
      scope.repair = function (id) { callEngine('repairVehicle', id); };
      scope.list = function (id) { callEngine('listVehicle', id); };
      scope.sell = function (id) { callEngine('sellVehicle', id); };
      scope.advanceDay = function () {
        if (window.bngApi && typeof bngApi.engineLua === 'function') {
          bngApi.engineLua('extensions.perekup_core.advanceDay()');
        }
      };
      scope.setTab = function (tab) { scope.tab = tab; };
      scope.garageCount = function () {
        if (!scope.snapshot.career) return 0;
        return scope.snapshot.career.vehicles.filter(function (car) { return car.status !== 'sold'; }).length;
      };
      scope.availableOffers = function () {
        if (!scope.snapshot.career) return [];
        return scope.snapshot.career.listings.filter(function (offer) { return offer.status === 'available'; });
      };
      scope.starterCar = function () {
        if (!scope.snapshot.career) return null;
        return scope.snapshot.career.vehicles.filter(function (car) { return car.id === scope.snapshot.career.starterVehicleId; })[0] || null;
      };
      scope.statusLabel = function (status) {
        return status === 'for_sale' ? 'На продаже' : status === 'sold' ? 'Продан' : 'В гараже';
      };

      snapshotListener = scope.$on('PerekupSnapshot', function (event, data) {
        scope.$evalAsync(function () {
          if (data && typeof data === 'object') {
            scope.snapshot = data;
          }
        });
      });
      scope.$on('$destroy', function () {
        if (snapshotListener) snapshotListener();
      });
      scope.refresh();
    }
  };
});
