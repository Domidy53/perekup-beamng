var perekupText = {
  ru: {
    eyebrow: 'КАРЬЕРА · FREE ROAM', refresh: 'Обновить', savedCareer: 'СОХРАНЁННАЯ КАРЬЕРА · ДЕНЬ {day}',
    continueTitle: 'Продолжить дело?', balance: 'Баланс', carsGarage: 'Машин в гараже', continue: 'Продолжить карьеру',
    saveUnavailable: 'Сохранение недоступно', saveNotOverwritten: 'Карьера не будет перезаписана. Проверьте файл сохранения в папке settings пользовательской папки BeamNG.drive.',
    newBusiness: 'НОВОЕ ДЕЛО · 01', startSmall: 'Начните с малого', startDescription: 'Выберите доступную машину из каталога вашей игры. Она станет первой в гараже, а на баланс будет зачислено $500.',
    noCars: 'Машины не найдены', loadMap: 'Убедитесь, что уровень East Coast USA загружен и каталог автомобилей готов.', chooseCar: 'Выбрать машину',
    starterCount: 'В каталоге доступно {count} из 3 возможных стартовых машин.',
    physicalWarning: 'Машины создаются в игровом мире через BeamNG. Ремонт выполняет полный физический сброс выбранной машины. Повреждения BeamNG пока не считываются: процент состояния и оценка цены служат расчётами карьеры.',
    repairPending: 'Ожидается подтверждение игрового объекта. Операции с карьерой временно приостановлены.',
    business: 'Дело', market: 'Объявления', garage: 'Гараж', history: 'История',
    day: 'День', cars: 'В гараже', yourBusiness: 'Ваше дело', overviewDescription: 'Покупайте машины из каталога, оплачивайте ремонт и выставляйте их на перепродажу.',
    starterCar: 'Стартовая машина', starterUnavailable: 'Конфигурация сейчас недоступна. Запись сохранена.', openListings: 'Открыть объявления', nextDay: 'Следующий день', dailyRefresh: 'Объявления обновляются на следующий день. Действия и баланс сохраняются локально.',
    usedEstimate: 'оценка подержанной машины', baseEstimate: 'Базовая оценка', valueField: 'поле Value из данных BeamNG', featureEstimate: 'расчёт по характеристикам',
    config: 'Конфигурация', modelId: 'ID модели', sections: 'Разделы карьеры', conditionEstimate: 'оценка состояния', buy: 'Купить', noOffers: 'Новых объявлений нет',
    noOffersHelp: 'Перейдите к следующему дню или установите совместимый автомобильный мод.', updateDay: 'Обновить день',
    property: 'СОБСТВЕННОСТЬ', ownership: 'Игровой объект', inWorld: 'в мире', inGarage: 'в гараже', forSale: 'На продаже', sold: 'Продан',
    retrieve: 'Вывести в мир', returnGarage: 'Вернуть в гараж', condition: 'Оценка состояния',
    unavailableConfig: 'Конфигурация недоступна в текущей установке. Запись о машине сохранена.',
    repairExpenses: 'Расходы на ремонт', salePrice: 'Цена продажи', physicalReset: 'Физический сброс', listForSale: 'Выставить', sellFor: 'Продать за',
    emptyGarage: 'Гараж пуст', deals: 'СДЕЛКИ И РЕШЕНИЯ', dayPrefix: 'День',
    emptyHistory: 'История пока пуста', language: 'Язык', offline: 'Работает локально · Без сетевых запросов · Цены примерные'
  },
  en: {
    eyebrow: 'CAREER · FREE ROAM', refresh: 'Refresh', savedCareer: 'SAVED CAREER · DAY {day}',
    continueTitle: 'Continue your business?', balance: 'Balance', carsGarage: 'Cars in garage', continue: 'Continue career',
    saveUnavailable: 'Save unavailable', saveNotOverwritten: 'The career will not be overwritten. Check the save in the settings folder of your BeamNG.drive user folder.',
    newBusiness: 'NEW BUSINESS · 01', startSmall: 'Start small', startDescription: 'Choose an available vehicle from your game catalog. It will be your first car, and you will receive $500.',
    noCars: 'No vehicles found', loadMap: 'Make sure East Coast USA is loaded and the vehicle catalog is ready.', chooseCar: 'Choose vehicle',
    starterCount: '{count} of 3 possible starter vehicles are available.',
    physicalWarning: 'Vehicles are created in the BeamNG world. Repair performs a full physics reset of the selected vehicle. BeamNG damage is not read yet: condition and price are career estimates.',
    repairPending: 'Waiting for the game object to confirm. Career actions are temporarily paused.',
    business: 'Business', market: 'Listings', garage: 'Garage', history: 'History',
    day: 'Day', cars: 'In garage', yourBusiness: 'Your business', overviewDescription: 'Buy vehicles from the catalog, pay for repairs, and list them for resale.',
    starterCar: 'Starter vehicle', starterUnavailable: 'Configuration is currently unavailable. The record is saved.', openListings: 'Open listings', nextDay: 'Next day', dailyRefresh: 'Listings refresh the next day. Actions and balance are saved locally.',
    usedEstimate: 'used vehicle estimate', baseEstimate: 'Base estimate', valueField: 'BeamNG Value field', featureEstimate: 'estimate from specifications',
    config: 'Configuration', modelId: 'Model ID', sections: 'Career sections', conditionEstimate: 'estimated condition', buy: 'Buy', noOffers: 'No new listings',
    noOffersHelp: 'Advance to the next day or install a compatible vehicle mod.', updateDay: 'Advance day',
    property: 'OWNED VEHICLES', ownership: 'Game object', inWorld: 'in world', inGarage: 'in garage', forSale: 'For sale', sold: 'Sold',
    retrieve: 'Spawn into world', returnGarage: 'Return to garage', condition: 'Estimated condition',
    unavailableConfig: 'Configuration is unavailable in this installation. The ownership record is saved.',
    repairExpenses: 'Repair expenses', salePrice: 'Sale price', physicalReset: 'Physics reset', listForSale: 'List for sale', sellFor: 'Sell for',
    emptyGarage: 'The garage is empty', deals: 'DEALS AND DECISIONS', dayPrefix: 'Day',
    emptyHistory: 'No history yet', language: 'Language', offline: 'Runs locally · No network requests · Prices are estimates'
  }
};

angular.module('beamng.apps').directive('perekupApp', function () {
  return {
    restrict: 'E',
    replace: false,
    require: '^bngApp',
    template: `
      <section class="perekup-app">
        <link type="text/css" rel="stylesheet" href="/ui/modules/apps/perekup/app.css" />
        <header class="perekup-header">
          <div>
            <div class="perekup-eyebrow" ng-bind="tr('eyebrow')"></div>
            <h1>ПЕРЕКУП</h1>
          </div>
          <div class="perekup-header-tools">
            <select class="perekup-language-select" ng-model="language" ng-options="item.id as item.name for item in languages" ng-attr-aria-label="{{tr('language')}}"></select>
            <button class="perekup-icon-button" ng-click="refresh()" ng-attr-title="{{tr('refresh')}}" ng-attr-aria-label="{{tr('refresh')}}">↻</button>
          </div>
        </header>

        <div class="perekup-continue" ng-if="snapshot.status === 'active' && !careerOpen">
          <span class="perekup-step" ng-bind="tr('savedCareer', {day: snapshot.career.day})"></span>
          <h2 ng-bind="tr('continueTitle')"></h2>
          <p>{{tr('balance')}} &#36;{{snapshot.career.money | number:0}} · {{tr('carsGarage')}} {{garageCount()}}</p>
          <button class="perekup-primary" ng-click="continueCareer()" ng-bind="tr('continue')"></button>
        </div>

        <div class="perekup-stats" ng-if="snapshot.status === 'active' && careerOpen">
          <div><span ng-bind="tr('balance')"></span><strong>{{snapshot.career.money | number:0}} $</strong></div>
          <div><span ng-bind="tr('day')"></span><strong>{{snapshot.career.day}}</strong></div>
          <div><span ng-bind="tr('cars')"></span><strong>{{garageCount()}}</strong></div>
        </div>

        <div class="perekup-message" ng-if="snapshot.message" ng-bind="snapshot.message"></div>
        <div class="perekup-warning" ng-if="snapshot.warning" ng-bind="snapshot.warning"></div>
        <div class="perekup-warning" ng-if="snapshot.catalogError" ng-bind="snapshot.catalogError"></div>

        <div class="perekup-error" ng-if="snapshot.status === 'error'">
          <h2 ng-bind="tr('saveUnavailable')"></h2>
          <p ng-bind="tr('saveNotOverwritten')"></p>
        </div>

        <div class="perekup-new" ng-if="snapshot.status === 'new'">
          <div class="perekup-intro">
            <span class="perekup-step" ng-bind="tr('newBusiness')"></span>
            <h2 ng-bind="tr('startSmall')"></h2>
            <p ng-bind="tr('startDescription')"></p>
          </div>
          <div class="perekup-empty" ng-if="snapshot.starterOptions.length === 0">
            <strong ng-bind="tr('noCars')"></strong>
            <span ng-bind="tr('loadMap')"></span>
          </div>
          <article class="perekup-card perekup-starter" ng-repeat="car in snapshot.starterOptions track by car.id">
            <div class="perekup-card-title"><strong ng-bind="car.displayName"></strong><span ng-bind="car.type"></span></div>
            <div class="perekup-card-meta">{{tr('config')}}: <span ng-bind="car.configName"></span> · {{tr('modelId')}}: <code ng-bind="car.modelKey"></code></div>
            <button class="perekup-primary" ng-click="startCareer(car.id)" ng-bind="tr('chooseCar')"></button>
          </article>
          <p class="perekup-footnote" ng-if="snapshot.starterOptions.length > 0 && snapshot.starterOptions.length < 3">
            {{tr('starterCount', {count: snapshot.starterOptions.length})}}
          </p>
        </div>

        <div class="perekup-active" ng-if="snapshot.status === 'active' && careerOpen">
          <div class="perekup-warning" role="note" ng-bind="tr('physicalWarning')"></div>
          <div class="perekup-message" ng-if="snapshot.career.pendingRepair" ng-bind="tr('repairPending')"></div>
          <nav class="perekup-tabs" ng-attr-aria-label="{{tr('sections')}}">
            <button ng-class="{selected: tab === 'overview'}" ng-click="setTab('overview')" ng-bind="tr('business')"></button>
            <button ng-class="{selected: tab === 'market'}" ng-click="setTab('market')" ng-bind="tr('market')"></button>
            <button ng-class="{selected: tab === 'garage'}" ng-click="setTab('garage')" ng-bind="tr('garage')"></button>
            <button ng-class="{selected: tab === 'history'}" ng-click="setTab('history')" ng-bind="tr('history')"></button>
          </nav>

          <div class="perekup-panel" ng-if="tab === 'overview'">
            <div class="perekup-intro compact">
              <span class="perekup-step">{{tr('day')}} {{snapshot.career.day}}</span>
              <h2 ng-bind="tr('yourBusiness')"></h2>
              <p ng-bind="tr('overviewDescription')"></p>
            </div>
            <div class="perekup-car-highlight" ng-if="starterCar()">
              <span ng-bind="tr('starterCar')"></span>
              <strong ng-bind="starterCar().displayName"></strong>
              <span ng-if="starterCar().modelAvailable === false" class="perekup-missing" ng-bind="tr('starterUnavailable')"></span>
            </div>
            <div class="perekup-row-actions">
              <button class="perekup-secondary" ng-click="setTab('market')" ng-bind="tr('openListings')"></button>
              <button class="perekup-primary" ng-click="advanceDay()" ng-bind="tr('nextDay')"></button>
            </div>
            <p class="perekup-footnote" ng-bind="tr('dailyRefresh')"></p>
          </div>

          <div class="perekup-panel" ng-if="tab === 'market'">
            <div class="perekup-section-heading"><div><span class="perekup-step">{{tr('day')}} {{snapshot.career.day}}</span><h2 ng-bind="tr('market')"></h2></div><span class="perekup-count">{{snapshot.career.listings.length}}</span></div>
            <article class="perekup-card" ng-repeat="offer in snapshot.career.listings track by offer.id" ng-if="offer.status === 'available'">
              <div class="perekup-card-title"><strong ng-bind="offer.displayName"></strong><span ng-bind="offer.type"></span></div>
              <div class="perekup-price-line"><strong>{{offer.price | number:0}} $</strong><span ng-bind="tr('usedEstimate')"></span></div>
              <div class="perekup-card-meta">{{tr('baseEstimate')}}: {{offer.marketValue | number:0}} $ · {{offer.valueSource === 'metadata' ? tr('valueField') : tr('featureEstimate')}}</div>
              <div class="perekup-card-meta">{{tr('config')}}: <span ng-bind="offer.configName"></span> · {{tr('conditionEstimate')}}: 35% · ID <code ng-bind="offer.modelKey"></code></div>
              <button class="perekup-primary" ng-click="buy(offer.id)" ng-disabled="snapshot.career.money < offer.price || snapshot.career.pendingRepair" ng-bind="tr('buy')"></button>
            </article>
            <div class="perekup-empty" ng-if="availableOffers().length === 0">
              <strong ng-bind="tr('noOffers')"></strong><span ng-bind="tr('noOffersHelp')"></span>
              <button class="perekup-secondary" ng-click="advanceDay()" ng-bind="tr('updateDay')"></button>
            </div>
          </div>

          <div class="perekup-panel" ng-if="tab === 'garage'">
            <div class="perekup-section-heading"><div><span class="perekup-step" ng-bind="tr('property')"></span><h2 ng-bind="tr('garage')"></h2></div><span class="perekup-count">{{snapshot.career.vehicles.length}}</span></div>
            <article class="perekup-card" ng-repeat="car in snapshot.career.vehicles track by car.id" ng-if="car.status !== 'sold'">
              <div class="perekup-card-title"><strong ng-bind="car.displayName"></strong><span ng-bind="statusLabel(car.status, car.inWorld)"></span></div>
              <div class="perekup-condition"><div><span ng-bind="tr('condition')"></span><strong>{{car.condition}}%</strong></div><div class="perekup-meter"><i ng-style="{width: car.condition + '%'}"></i></div></div>
              <div class="perekup-card-meta">{{tr('ownership')}}: {{car.inWorld ? tr('inWorld') : tr('inGarage')}}</div>
              <div class="perekup-missing" ng-if="car.modelAvailable === false" ng-bind="tr('unavailableConfig')"></div>
              <div class="perekup-card-meta" ng-if="car.repairCost > 0">{{tr('repairExpenses')}}: {{car.repairCost | number:0}} $</div>
              <div class="perekup-card-meta" ng-if="car.status === 'for_sale'">{{tr('salePrice')}}: {{car.askingPrice | number:0}} $</div>
              <div class="perekup-row-actions" ng-if="car.status === 'owned'">
                <button class="perekup-secondary" ng-if="!car.inWorld" ng-click="retrieve(car.id)" ng-disabled="car.modelAvailable === false" ng-bind="tr('retrieve')"></button>
                <button class="perekup-secondary" ng-if="car.inWorld" ng-click="returnToGarage(car.id)" ng-bind="tr('returnGarage')"></button>
              </div>
              <div class="perekup-row-actions" ng-if="car.status === 'owned'">
                <button class="perekup-secondary" ng-click="repair(car.id)" ng-disabled="!car.inWorld || car.repairUsed || car.condition >= 100 || snapshot.career.money < car.repairQuote || snapshot.career.pendingRepair">{{tr('physicalReset')}} · {{car.repairQuote | number:0}} $</button>
                <button class="perekup-primary" ng-click="list(car.id)" ng-disabled="car.inWorld || snapshot.career.pendingRepair" ng-bind="tr('listForSale')"></button>
              </div>
              <button class="perekup-primary" ng-if="car.status === 'for_sale'" ng-click="sell(car.id)" ng-disabled="car.inWorld || snapshot.career.pendingRepair">{{tr('sellFor')}} {{car.askingPrice | number:0}} $</button>
            </article>
            <div class="perekup-empty" ng-if="snapshot.career.vehicles.length === 0"><strong ng-bind="tr('emptyGarage')"></strong></div>
          </div>

          <div class="perekup-panel" ng-if="tab === 'history'">
            <div class="perekup-section-heading"><div><span class="perekup-step" ng-bind="tr('deals')"></span><h2 ng-bind="tr('history')"></h2></div><span class="perekup-count">{{snapshot.career.history.length}}</span></div>
            <article class="perekup-history-item" ng-repeat="entry in snapshot.career.history track by entry.id">
              <span class="perekup-history-day">{{tr('dayPrefix')}} {{entry.day}}</span><strong ng-bind="entry.description"></strong>
              <span class="perekup-history-amount" ng-class="{positive: entry.amount > 0, negative: entry.amount < 0}">{{entry.amount > 0 ? '+' : ''}}{{entry.amount | number:0}} $ · {{tr('balance')}} {{entry.balanceAfter | number:0}} $</span>
            </article>
            <div class="perekup-empty" ng-if="snapshot.career.history.length === 0"><strong ng-bind="tr('emptyHistory')"></strong></div>
          </div>
        </div>

        <footer class="perekup-footer" ng-bind="tr('offline')"></footer>
      </section>
    `,
    link: function (scope, element, attrs, appCtrl) {
      var snapshotListener;
      scope.tab = 'overview';
      scope.careerOpen = false;
      scope.language = 'ru';
      scope.languages = [{ id: 'ru', name: 'Русский' }, { id: 'en', name: 'English' }];
      scope.snapshot = { status: 'loading', starterOptions: [] };

      scope.tr = function (key, values) {
        var language = perekupText[scope.language] ? scope.language : 'ru';
        var result = perekupText[language][key] || perekupText.ru[key] || key;
        Object.keys(values || {}).forEach(function (name) {
          result = result.split('{' + name + '}').join(String(values[name]));
        });
        return result;
      };

      var appSettings = {};
      var settingsLoaded = false;
      element.ready(function () {
        if (!appCtrl || typeof appCtrl.getSettings !== 'function') return;
        appCtrl.getSettings().then(function (settings) {
          appSettings = settings || {};
          var preferred = appSettings.language;
          if (preferred !== 'ru' && preferred !== 'en') {
            preferred = window.navigator && /^ru/i.test(window.navigator.language || '') ? 'ru' : 'en';
          }
          scope.$evalAsync(function () {
            scope.language = preferred;
            settingsLoaded = true;
          });
        }, function () {
          settingsLoaded = true;
        });
      });
      scope.$watch('language', function (language) {
        if (!settingsLoaded || (language !== 'ru' && language !== 'en')) return;
        appSettings.language = language;
        if (appCtrl && typeof appCtrl.saveSettings === 'function') {
          appCtrl.saveSettings(appSettings);
        }
      });

      function safeId(value) {
        return typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
      }

      function callEngine(method, id) {
        var allowed = ['startCareer', 'buyListing', 'repairVehicle', 'listVehicle', 'sellVehicle', 'retrieveVehicle', 'returnVehicle'];
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
      scope.retrieve = function (id) { callEngine('retrieveVehicle', id); };
      scope.returnToGarage = function (id) { callEngine('returnVehicle', id); };
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
      scope.statusLabel = function (status, inWorld) {
        if (inWorld) return scope.tr('inWorld');
        return status === 'for_sale' ? scope.tr('forSale')
          : status === 'sold' ? scope.tr('sold')
          : scope.tr('inGarage');
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
