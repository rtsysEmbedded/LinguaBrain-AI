# Tasks — 004: یادگیری پویای چهار مهارت

تاریخ: 2026-09-06. وضعیت: T001 تا T012 با شواهد audit/build/test تکمیل شده‌اند؛ T013 و بعد از آن باز هستند.

ورودی‌ها: [spec.md](spec.md)، [plan.md](plan.md) و تصمیم‌های مرجع آن‌ها. این فایل، کاربرگ اجرایی است؛ معیارهای هر تسک بخشی از تعریف پایان آن هستند. شناسهٔ کامل هنگام واگذاری `004/Txxx` است تا با تسک‌های ویژگی‌های قبلی اشتباه نشود.

## قواعد تحویل و مالکیت

- پیش از کدنویسی، `AGENTS.md`، constitution، spec، plan و تسک واگذارشده خوانده شود. وضعیت Git و تغییرات موجود بررسی شود؛ حذف یا بازنویسی تغییرات دیگران ممنوع است.
- مسیرهای زیر نسبت به ریشهٔ مخزن‌اند. فایل‌های جدید، مقصد پیشنهادی مشخص دارند؛ تغییر نام مجاز است اگر پیش از شروع موازی در plan و قراردادها ثبت شود. ساخت مدل موازی برای موجودیت‌های موجود مجاز نیست.
- هر تسک: ورودی و وابستگی مشخص، خروجی کوچک قابل بررسی، معیار پذیرش، آزمون متناسب و گزارش فایل‌های تغییرکرده/شواهد/محدودیت‌ها. صرف Build موفق، پایان تسک آموزشی نیست.
- دسترسی مستقیم View به Provider، SQL، SwiftData یا زمان‌بند در کد جدید ممنوع است. Feature Model فقط فرمان کاربردی می‌فرستد؛ امتیاز و موعد مرور را Application/Domain تعیین می‌کنند.
- فایل‌های `PrototypeModels.swift`، `ReviewPrototypeView.swift`، مسیرهای اصلی برنامه، catalogهای زبان، `Package.swift` و `project.pbxproj` یک مالک ادغام دارند. تیم‌های داستانی به‌جای ویرایش هم‌زمان آن‌ها، فایل‌های مستقل و کلیدهای پیشنهادی تحویل دهند.
- `[P]` یعنی پس از تکمیل وابستگی‌های نوشته‌شده می‌تواند کنار کار مستقل اجرا شود؛ اجازهٔ عبور از وابستگی نیست. در یک task هم‌زمان دو نویسنده نگذارید.
- تغییر Apple API نیازمند بررسی SDK محلی 27 و مستند رسمی فعلی است. تفاوت toolchain با baseline طبق `AGENTS.md` ثبت و حل شود. برای دادهٔ واقعی، شرط حفاظت/بازیابی ADR-003 رعایت شود.

## فاز ۱ — تثبیت محدوده و قرارداد

- [x] T001 ثبت محدودهٔ چهار مهارت و تغییر نقشهٔ راه در `specs/004-adaptive-skill-practice/spec.md`، `docs/10_MVP_Definition_and_Roadmap.md`، `PROJECT_STATUS.md`، `CHANGELOG.md` و یک ADR با شمارهٔ آزاد بعدی در `decisions/`.
  - وابستگی: ندارد. مالک: معمار/هماهنگ‌کننده.
  - خروجی: تطبیق خواسته‌ها با نسخهٔ هدف؛ حفظ Anki/offline gate؛ تعیین رابطه با 001/T025–T027/T031 و کارهای صوت؛ اصلاح ادعای تکمیل بیش از شواهد در وضعیت پروژه.
  - پذیرش: حذف تعارض «تلفظ خارج از محدوده/در حال اجرا» با تصمیم مستند؛ هیچ ADR بدون مرجع پذیرش، accepted نشود. باقی‌ماندهٔ کارهای قدیمی گم یا دوباره اجرا نشود. اگر پذیرش تصمیم لازم است، پیشنهاد کامل قابل بررسی آماده شود.

- [x] T002 تهیهٔ قرارداد هسته و مسیر ذخیره‌سازی در `specs/004-adaptive-skill-practice/data-model.md`، `specs/004-adaptive-skill-practice/contracts/practice.md`، `specs/004-adaptive-skill-practice/research.md` و تکمیل `specs/004-adaptive-skill-practice/plan.md`.
  - وابستگی: T001. مالک: معمار هسته.
  - خروجی: شناسه/نسخهٔ Sentence و ReviewUnit، attempt/event، state machine، taxonomy خطا، schema ارزیابی و سیاست نسخه‌دار امتیاز؛ مشخص‌کردن reuse/correction/skip/assistance، معنای partial/confidence و بازهٔ نمره. جدول نگاشت داده‌های legacy و مالک persistence موجود.
  - پذیرش: برای هر حالت اثر دقیق بر history/mastery/FSRS نوشته شود؛ اگر backend استاندارد وجود ندارد، T005/T006 مسئول slice سازگار با ADR-003 باشند. قرارداد cutover و حفاظت/بازیابی دادهٔ واقعی روشن باشد؛ نه dual-write و نه تصمیم ضمنی برای تولید با SwiftData. شماره و محل ADR لازم را ثبت کنید. این تسک باید پیش از پراکندن کد بین تیم‌ها بسته شود.
  - شواهد تکمیل: ماتریس اثر stateها، سیاست عددی نسخه‌دار و مثال‌های fixed-clock در `data-model.md` و `contracts/practice.md`؛ مرز فعلی پیاده‌سازی/باقی‌مانده در `research.md` و `verification.md` ثبت شده است. مرز persistence و cutover به‌ترتیب در `decisions/ADR-003-Swift-Persistence-and-Migration-Stack.md` و `decisions/ADR-017-Feature-004-Practice-Core-Scope.md` ثبت شده‌اند. T006 و T007 اکنون شواهد اجرای خود را دارند.

## فاز ۲ — هستهٔ مشترک و قابل‌آزمون

- [x] T003 توسعهٔ مدل‌های موجود و افزودن انواع تمرین در `packages/LinguaBrainKit/Sources/LinguaBrainDomain/LinguaBrainDomain.swift` و `packages/LinguaBrainKit/Sources/LinguaBrainDomain/Practice/PracticeTypes.swift`.
  - وابستگی: T002. مالک: Domain.
  - خروجی: Sentence با شناسه و revision؛ ReviewUnit مستقل؛ ExerciseInstance، Attempt، HelpEvent، TypedFeedback و RuleReference براساس قرارداد؛ وضعیت unknown جدا از zero mastery.
  - پذیرش: نوع‌ها مستقل از SwiftUI/SwiftData/Provider باشند؛ source/target/UI language تفکیک شوند؛ original/minimal correction/natural variant همدیگر را overwrite نکنند. سازگاری generation/export و mappingهای `Sentence` فعلی حفظ و آزموده شود.
  - شواهد تکمیل: `ReviewUnit` برای همان learner/objective/skill/sentence revision شناسهٔ deterministic و stableKey یکسان دارد؛ `Sentence` revision-safe و immutable است و پاسخ اصلی، correction، natural variant، validation، provenance و rule/lexical references را جدا نگه می‌دارد؛ `Attempt` تمام outcomeهای قراردادی، first-attempt، evaluator evidence، confidence، idempotency و eventهای کمک را مدل می‌کند؛ state transitionهای قانونی و mastery `unknown` در تست‌های fixed-ID/fixed-date پوشش داده شده‌اند. Domain هیچ import پلتفرم، persistence یا provider ندارد و T004 هنوز مسئول اتصال persistence/policy است.

- [x] T004 ایجاد portها و سیاست ارزیابی در `packages/LinguaBrainKit/Sources/LinguaBrainApplication/Practice/PracticePorts.swift` و `packages/LinguaBrainKit/Sources/LinguaBrainDomain/Practice/PracticeEvidencePolicy.swift`.
  - وابستگی: T003. مالک: Application/Domain.
  - خروجی: port ذخیرهٔ تلاش، خواندن تمرین/جمله، ارزیابی متنی، صوت مرجع، ضبط و ارزیابی تلفظ؛ request/revision IDs، typed errors، cancellation؛ policy قطعی تبدیل شواهد به اثر آموزشی.
  - پذیرش: reveal/copy retry موفقیت مستقل نسازند؛ skip با wrong متفاوت باشد؛ timeout/unavailable نمرهٔ غلط ندهد؛ اولین خطا حفظ شود و تکرار اصلاحی به چند retrieval مستقل تبدیل نشود. سیاست در جدول T002 مثال عددی داشته و با ساعت ثابت قابل تست باشد.
  - شواهد تکمیل: `EvaluationResult` خروجی‌های validated برای outcome، score/confidence، feedback/rules، evaluator version، provenance و reasonهای unavailable را حمل می‌کند؛ portهای مستقل retrieval، attempt/help persistence، evaluation، media و review/mastery scheduling تعریف شده‌اند؛ policy `practice-evidence-v1` تمام outcomeها و assistanceهای hint/reveal/copy/retry/skip را deterministic نگاشت می‌کند. low-confidence، malformed، pending و transport/cancellation به unavailable/ungraded می‌روند و هیچ provider یا evaluator دسترسی mutation به persistence/mastery/schedule ندارد. تست‌های fixed-clock و provider-independent پاس شده‌اند.

- [x] T005 پیاده‌سازی repository و تراکنش تمرین در `packages/LinguaBrainKit/Sources/LinguaBrainPersistence/Practice/PracticeRepository.swift` و `packages/LinguaBrainKit/Sources/LinguaBrainPersistence/Practice/PracticeMigrations.swift`.
  - وابستگی: T004. مالک: Persistence؛ تغییر manifest تنها از مسیر هماهنگ‌کننده.
  - خروجی: adapter سازگار با GRDB 7 مصوب یا استفاده از backend سازگار موجود؛ جدول‌ها/constraints/indexهای لازم برای جملات، revision، attempts/events، units و projection؛ مالکیت داده و transaction API.
  - پذیرش: insert مجدد attempt اثر اضافی ندارد؛ خرابی تزریق‌شده هیچ حالت نیمه‌ثبت‌شده‌ای باقی نگذارد؛ ID ارجاعات معتبر باشد؛ داده پس از reopen حفظ شود؛ فایل‌های SQL/row/GRDB به بیرون adapter نشت نکنند. dependency جدید فقط با pin و سند بررسی؛ هیچ store نمایشی در production composition نباشد.
  - شواهد تکمیل: adapter تولیدی GRDB 7.11.1 از طریق dependency injection در app composition استفاده می‌شود؛ migrationهای ترتیبی، constraint/indexها، transaction rollback، reopen، idempotency و referential-integrity در package test و build-for-testing پاس شده‌اند. SwiftData/GRDB به Domain/Application نشت نمی‌کند.

- [x] T006 انتقال امن و مستقل‌سازی زمان‌بندی در `apps/learner/App/Practice/LegacyPracticeMigration.swift`، `packages/LinguaBrainKit/Sources/LinguaBrainApplication/Practice/PracticeReviewService.swift` و اتصال کنترل‌شده در `apps/learner/App/PrototypeModels.swift`.
  - وابستگی: T005. مالک: Persistence + هماهنگ‌کننده، اجرای ترتیبی.
  - خروجی: bridge و cutover یک‌باره طبق T002؛ adapter زمان‌بند pinned FSRS پشت port؛ حفظ card references و legacy recognition/reverse history؛ واحدهای مستقل برای writing/listening/grammar/speaking.
  - شواهد تکمیل: `PracticeReviewService` تنها مرز Application برای تبدیل evidence به mastery/FSRS است؛ attempt، learning event و projection را در یک transaction ذخیره می‌کند، با event/attempt ID idempotent است، و scheduler نسخهٔ `FSRS-6.0/default-21` را فقط برای evidence مستقل فراخوانی می‌کند. partial با `hard` و نمرهٔ `0.50`، correct با `good` و `1.00`، incorrect با `again` و `0.00`، و skip/reveal/copy/unavailable بدون اثر مستقل نگاشت می‌شوند. تست fixed-clock، retry، duplicate، چهار skill مستقل، rollback و GRDB reopen این شواهد را پوشش می‌دهد؛ migration bridge همچنان synthetic/read-only است و live cutover انجام نشده است.
  - شواهد موجود: app bridge، backup manifest/hash، read-only SwiftData snapshot، staging/checkpoint/digest، validation، GRDB activation gate، source retention و recovery action در `apps/learner/App/Practice/LegacyPracticeMigration.swift` پیاده شده‌اند. stateهای session در T007 و review/mastery/FSRS boundary در T006 پیاده شده‌اند.
  - پذیرش: تاریخ‌ها و stateهای قدیمی بدون تغییر ناخواسته حفظ شوند؛ پاسخ گرامر موعد listening/recognition را تغییر ندهد؛ تاریخچهٔ مبهم به چند مهارت کپی نشود؛ قطع انتقال و اجرای مجدد idempotent باشد؛ source قدیمی برای بازیابی باقی بماند؛ همهٔ نویسنده‌ها از مسیر مالک تعیین‌شده استفاده کنند.

- [x] T007 سرویس جلسه و ارسال پاسخ را در `packages/LinguaBrainKit/Sources/LinguaBrainApplication/Practice/PracticeSessionService.swift` پیاده کنید.
  - وابستگی: T006. مالک: Application.
  - خروجی: prepare، submit، requestHint، reveal، retry، continue، resume؛ ذخیرهٔ پاسخ قبل از AI و ثبت نتیجهٔ معتبر با تراکنش؛ شناسهٔ نسل درخواست برای رد نتیجهٔ دیرهنگام.
  - پذیرش: دوبار لمس submit/next یک اثر ایجاد کند؛ خروج هنگام بررسی و نتیجهٔ دیرهنگام سؤال قبلی اثر نگذارند؛ خطای ذخیره باعث نمایش موفقیت نشود؛ جلسهٔ خالی/تمام‌شده loading دائمی نداشته باشد؛ تکرار سؤال غلط سقف مشخص داشته باشد.
  - شواهد تکمیل: سرویس `PracticeReviewService` را برای تمام نتیجه‌ها مصرف می‌کند؛ draft/pending attempt و help/eventهای hint، reveal، copy و retry را پیش از evaluator در transaction ذخیره می‌کند؛ skip را به‌صورت outcome مستقل و بدون mastery/FSRS ثبت می‌کند؛ duplicate submit، continue، retry، cancellation و نتیجهٔ دیرهنگام نسل قدیمی idempotent هستند؛ `resume` از GRDB state دوام‌دار را بازسازی می‌کند و سقف retry برابر چهار attempt است (قابل تزریق برای تست). ۱۳ تست fixed-clock در `PracticeSessionTests.swift` و کل suite، هر دو build پلتفرم، و `git diff --check` پاس شده‌اند.

- [x] T008 ساخت fakeها و آزمون‌های هسته در `packages/LinguaBrainKit/Sources/LinguaBrainTestSupport/PracticeFakes.swift`، `packages/LinguaBrainKit/Tests/LinguaBrainDomainTests/PracticeEvidencePolicyTests.swift`، `packages/LinguaBrainKit/Tests/LinguaBrainApplicationTests/PracticeSessionTests.swift` و تست معادل app-level در `apps/learner/Tests/LegacyPracticeMigrationTests.swift`.
  - وابستگی: T007. مالک: آزمون هسته.
  - خروجی: fixed clock/IDs، fake evaluator/media، file-backed restart/migration suite؛ ثبت wiring هدف‌های تست از مسیر هماهنگ‌کننده.
  - پذیرش: شواهد قابل‌تکرار برای استقلال زمان‌بندی، کمک/نمایش پاسخ، replay/double tap، rollback، late response، migration interruption و عدم افت generation/export موجود. CI بدون شبکه و کلید اجرا شود. آزمون‌ها رفتار محصول را بسنجند.
  - شواهد تکمیل: فیک‌های `FixedPracticeClock`، `FixedPracticeIDs`، evaluator/scripted cancellation و late release، media، scheduler و repository failure-injection در `PracticeFakes.swift` اضافه شدند؛ چهار تست deterministic آن‌ها را با review service، rollback و چهار skill اجرا می‌کنند. تست‌های موجود Domain/Application/Persistence، تست‌های app-level در `LegacyPracticeMigrationTests.swift`، و regressionهای generation/APKG کل ماتریس acceptance را پوشش می‌دهند. مسیر `PracticeMigrationTests.swift` در نسخهٔ اولیه وجود نداشت؛ طبق plan، `LegacyPracticeMigrationTests.swift` به‌عنوان جایگزین دقیق و comprehensive ثبت شده است.

دروازهٔ هسته: T001–T008 کامل؛ قراردادها ثابت، ذخیره و زمان‌بندی قابل اعتماد. پژوهش مستقل T028 می‌تواند زودتر شروع شود، ولی اجرای داستان‌ها از این دروازه عبور می‌کند.

## فاز ۳ — US1: پوستهٔ قابل‌فهم و کمک آموزشی

آزمون مستقل: با سرویس fake در هر چهار mode پاسخ خالی، راهنما، reveal، retry، next و پایان جلسه را طی کنید؛ هیچ‌کدام نیازمند Provider واقعی نباشد.

- [x] T009 [US1] استخراج رابط و Feature Model در `apps/learner/App/Practice/Shared/PracticeSessionModel.swift` و `apps/learner/App/Practice/PracticeComposition.swift`؛ مسیر چهارمهارت فعلی به مرز جدید متصل شد و مسیر recognition/reverse قدیمی محفوظ ماند.
  - وابستگی: T008. مالک: هماهنگ‌کننده/UI.
  - پذیرش: `@MainActor @Observable` با use case تزریق‌شده؛ Views فقط intent؛ local/cloud/off و test composition از یک interface؛ مسیرهای recognition/reverse فعلی محفوظ. تنظیم endpoint/credential در composition، نه مدل UI.
  - شواهد تکمیل: `PracticeSessionModel` تمام stateهای presentation قراردادی را به‌صورت immutable نگاشت می‌کند و فقط intentهای نام‌گذاری‌شده را به use case تزریق‌شده می‌فرستد؛ نسل درخواست، cancellation و stale-result suppression پیاده‌سازی و در ۹ تست app-level بررسی شده‌اند. `PracticeComposition` مسیر production را با repository/scheduler/clock/evaluator تزریق‌شده می‌سازد و composition تستی نیز همان interface را مصرف می‌کند؛ هیچ fake تمرین، GRDB، SwiftData یا provider SDK به View/Model نشت نمی‌کند. چهار لینک skill practice از Today به boundary جدید متصل‌اند، و پوستهٔ مشترک در T010 تکمیل شده است؛ exercise factory و QA نهاییِ تمام سطوح به T011 واگذار شده و `SkillPracticeView` قدیمی محفوظ است.

- [x] T010 [US1] ساخت پوسته و کمک مرحله‌ای در `apps/learner/App/Practice/Shared/PracticeScaffold.swift` و `apps/learner/App/Practice/Shared/PracticeFeedbackView.swift`.
  - وابستگی: T009. مالک: UI مشترک.
  - خروجی: instruction، prompt، answer area، hint، show answer، next و summary با فونت semantic و چیدمان قابل scroll؛ کنترل‌های سازگار با عرض کم؛ label و focus مناسب.
  - پذیرش: پس از reveal کنترل «سؤال بعدی» واضح باشد؛ راهنما پیش از پاسخ کامل مرحله‌بندی داشته باشد؛ readonly feedback پاسخ اصلی را حفظ کند؛ revealed/assisted در summary مشخص باشند؛ «پاسخ درست» برای جمله‌سازی با «نمونهٔ پاسخ» اشتباه نشود.
  - شواهد تکمیل: پوستهٔ مشترک هر ۹ حالت مدل را با پنل‌های finite و پیام‌های غیررنگی نمایش می‌دهد؛ prompt/answer/reveal به‌صورت closure تزریق می‌شوند و actionها فقط intentهای مدل را صدا می‌زنند. ScrollView، ViewThatFits، فونت‌های semantic، line spacing، control size، keyboard shortcut، accessibility labels/hints/sort priority و پشتیبانی RTL/LTR در `PracticeScaffold.swift` و `PracticeFeedbackView.swift` پیاده شده‌اند. Hint از reveal جداست، reveal و استفاده از پاسخ پیام صریحِ عدم کسب recall مستقل دارند، feedback پاسخ اصلی/نتیجه/توضیح/rule/model answer را نگه می‌دارد، و پاسخ مرجع فقط در وضعیت مجاز ساخته می‌شود. کلیدهای `practice.shared.*` در fa/en/de افزوده و ۱۱ تست app-level مدل/پوسته روی iPhone 17 Simulator (به‌همراه ۸ تست migration)، buildهای iOS/macOS و suite پکیج، پاس شدند. T011 مسئول smoke/render نهایی تمام سطوح و واژه‌نامهٔ مشترک باقی می‌ماند.

- [x] T011 [US1] آزمون پوسته و واژه‌نامهٔ مشترک در `apps/learner/Tests/PracticeSessionModelTests.swift` و `specs/004-adaptive-skill-practice/localization/shared.md`.
  - وابستگی: T010. مالک: UI QA.
  - پذیرش: تمام stateها، از دست نرفتن پاسخ، کمک قبل/بعد از ارزیابی و عدم دریافت نمرهٔ مستقل بعد از reveal تست شوند؛ کلیدها و مقادیر fa/en/de آمادهٔ merge باشند؛ جهت متن ورودی با زبان پاسخ باشد، نه زبان منو. smoke اولیه روی عرض کم و متن بزرگ ثبت شود.
  - شواهد تکمیل: نگاشت جهت زبان پاسخ در `PracticeLanguageDirection` برای fa/fa-IR و de-DE/en_US با رابط RTL تست شد و به editor و feedback اعمال شد؛ پاسخ مرجع پیش از reveal در policy/view ساخته یا وارد accessibility tree نمی‌شود. تست renderer با `.accessibility5`، رابط fa/RTL و answer زبان de روی عرض‌های 280، 320 و 744 برای answering، evaluating، feedback، revealed، unavailable، finished، empty و recoverable-failure پاس شد؛ loading نیز با delayed-operation/cancellation تست شد. کلیدهای `practice.shared.*` (۶۱ کلید) در هر سه catalog fa/en/de مقدار غیرخالی و غیرکلیدی دارند و JSON validation پاس شد. ترتیب semantic/accessibility label/value/hint/sort priority، Return/Tab-friendly controls، ScrollView و ViewThatFits در scaffold ثبت شده‌اند. مسیر manual VoiceOver و محدودیت نبودن UI assertion target/دستگاه فیزیکی در `localization/shared.md` و `verification.md` ثبت شده است؛ هیچ ادعای device فیزیکی یا live-data نشده است.

## فاز ۴ — US2: نگارش و اصلاح جمله

آزمون مستقل: فعل آلمانی همراه POS نمایش داده شود؛ جملهٔ درست و غلط ارسال شود؛ با fake و سپس Provider معتبر correction، explanation و natural variant دیده شود؛ خطای شبکه پاسخ را پاک نکند.

- [x] T012 [P] [US2] تعریف rubric و fixtureهای نگارش در `specs/004-adaptive-skill-practice/contracts/writing.md` و `packages/LinguaBrainKit/Tests/LinguaBrainAITests/Fixtures/practice-writing.json`.
  - وابستگی: T008. مالک: ارزیابی زبان.
  - پذیرش: نمونه‌های جملهٔ درست بدون اصلاح اجباری، صرف/فعل جداشدنی، خطای ترتیب فعل، واژهٔ بی‌ربط، تغییر معنی توسط AI، جملهٔ مبهم و پیشنهاد صرفاً سبکی پوشش داده شوند. داده مصنوعی و نتیجهٔ مرجع بررسی‌شده باشد.
  - شواهد تکمیل: قرارداد versioned `writing-evaluation-v1` ورودی زمینه، خروجی ساختاریافته، تمایز خطای دستور/واژگان/معنی/سبک، مسیرهای uncertainty/unavailable، محدودیت‌های متن/feedback/rule/span/score/confidence، provenance و ممنوعیت mutation canonical/mastery/schedule را تعریف می‌کند. fixture corpus شامل ۱۳ مورد synthetic است (۱۰ پذیرش، ۲ رد malformed/unsupported، و ۱ مورد normalize به unavailable برای confidence پایین) و همهٔ نمونه‌های پذیرش تسک را پوشش می‌دهد. `WritingEvaluationFixtureTests` با ۶ تست، schema/fixture validation، نبود correction غیرضروری، human-review برای تغییر معنی، و rejection اندازه/زبان/span/score/confidence/rule ناشناخته را اثبات می‌کند. هیچ network، credential یا live learner data استفاده نشده است.

- [x] T013 [US2] adapter اصلاح ساختاریافته در `packages/LinguaBrainKit/Sources/LinguaBrainAI/Practice/WritingEvaluationProvider.swift` و decoder مشترک در `packages/LinguaBrainKit/Sources/LinguaBrainAI/Practice/PracticeEvaluationDecoder.swift` بسازید.
  - وابستگی: T012. مالک: Text AI.
  - خروجی: rubric، prompt/schema version، provenance، typed feedback، confidence؛ استفاده از provider config/credential موجود از port؛ validation طول/spans/language/revision؛ محدودیت زمان و لغو.
  - پذیرش: fixtures معتبر/نامعتبر decode شوند؛ محتوای پاسخ به‌عنوان دادهٔ غیرقابل اعتماد پردازش شود؛ کم‌اطمینانی و تغییر معنی تأیید خودکار نشود؛ مدل/transport اختصاصی به هسته نشت نکند؛ متن خصوصی در log نباشد.
  - شواهد تکمیل: decoder `writing-evaluation-v1` با provenance/rubric/validator نسخه‌دار، زبان و revision، طول feedback و span، rule allow-list، score/confidence و ممنوعیت mutation را بررسی می‌کند؛ provider با transport و credential port تزریق‌شده کار می‌کند، cancellation/transport failure را ungraded نگه می‌دارد و تست‌های synthetic provider/decoder سبز هستند.

- [x] T014 [US2] تولید و اجرای تمرین نگارش در `packages/LinguaBrainKit/Sources/LinguaBrainApplication/Practice/WritingPracticeService.swift`.
  - وابستگی: T013. مالک: Application نگارش.
  - خروجی: انتخاب sense/word و POS معتبر در سطح کاربر؛ ارسال پاسخ از T007؛ آماده‌سازی correction proposal برای T016.
  - پذیرش: prompt اولیه واژهٔ مقصد و نقش آن را بدهد، نه ترجمه برای recall؛ جملهٔ دارای شکل صرفی معتبر صرفاً به‌خاطر نبود lemma رد نشود؛ local answer قبل از ارزیابی ذخیره شود؛ unavailable مسیر ungraded داشته باشد.
  - شواهد تکمیل: service از `WritingExerciseRetrieval` و `PracticeSessionService` تزریق‌شده استفاده می‌کند، descriptor شامل target word/POS/CEFR/context است، submit از مسیر save-before-evaluate عبور می‌کند و proposal اصلاح را بدون mutation canonical برمی‌گرداند؛ تست fixed fake حفظ پاسخ اصلی و partial/unavailable را پوشش می‌دهد.

- [x] T015 [US2] صفحه و آزمون نگارش در `apps/learner/App/Practice/Writing/WritingPracticeView.swift`، `apps/learner/Tests/WritingPracticeTests.swift` و کلیدها در `specs/004-adaptive-skill-practice/localization/writing.md`.
  - وابستگی: T011، T014. مالک: UI نگارش.
  - پذیرش: TextEditor چندخطی، واژه/POS، submit، اصلاح حداقلی، جملهٔ طبیعی‌تر و دلیل قابل‌تفکیک باشند؛ متن درست به‌عنوان غلط نمایش داده نشود؛ اقدام پذیرش correction به port sentence library متصل و با fake مستقل تست شود؛ offline/retry/reveal/next و کمک قابل استفاده باشند.
  - شواهد تکمیل: `WritingPracticeView` از scaffold مشترک و مدل intent-only استفاده می‌کند، metadata واژه/POS/CEFR و `TextEditor` چندخطی را نمایش می‌دهد و correction/natural variant را بدون جایگزینی پاسخ اصلی به `SentenceLearningService` تزریق‌شده می‌فرستد. سه تست `WritingPracticeTests` روی iPhone 17 Simulator در 2026-09-08 پاس شدند: surface/metadata و جهت زبان، پنهان‌بودن پاسخ مرجع پیش از evaluation، و پذیرش correction همراه با حفظ original response. مسیرهای offline/unavailable/retry/reveal/continue از تست‌های T007/T010 مدل و scaffold مشترک پوشش دارند؛ فایل در app target ثبت و build شد.

## فاز ۵ — US6: تبدیل پاسخ‌ها به یادگیری آینده

آزمون مستقل: correction بررسی‌شدهٔ seed را بپذیرید، برنامه را ببندید و باز کنید؛ تمرین بعدی از همان revision ساخته شود و با fixed clock/seed قابل بازتولید باشد. برای این آزمون منتظر تکمیل UI شنیداری یا تلفظ نمانید.

- [x] T016 [US6] کتابخانهٔ خصوصی جمله و پذیرش اصلاح در `packages/LinguaBrainKit/Sources/LinguaBrainApplication/Practice/SentenceLearningService.swift`.
  - وابستگی: T014. مالک: هستهٔ reuse.
  - خروجی: accept/edit/decline correction، revision immutable، parent attempt، minimal/natural variant، validation، rule/word links؛ dedup scopeدار به learner/language/meaning.
  - پذیرش: دو بار پذیرش رکورد تکراری نسازد؛ original محفوظ بماند؛ فقط متن معتبر و پذیرفته‌شده وارد pool شود؛ ویرایش معنی‌دار نیازمند بازاعتبارسنجی و تصمیم identity باشد؛ محتوای یک کاربر در تمرین کاربر دیگر ظاهر نشود.
  - شواهد تکمیل: `SentenceLearningService` پذیرش/رد/ویرایش را پشت `PracticeRepository` و transaction انجام می‌دهد؛ شناسهٔ sentence با learner/language/meaning scope می‌شود، پذیرش تکراری idempotent است، original immutable می‌ماند، edit بدون revalidation رد می‌شود و revision جدید می‌سازد. تست‌های deterministic برای duplicate، scope isolation، original preservation و revision immutability پاس شدند. UI تاریخچه و data ownership در T018/T034 باقی است.

- [x] T017 [US6] انتخاب تمرین براساس خطاها در `packages/LinguaBrainKit/Sources/LinguaBrainApplication/Practice/AdaptivePracticePlanner.swift` و اتصال محدود به `packages/LinguaBrainKit/Sources/LinguaBrainApplication/AdaptiveLearningPlanner.swift`.
  - وابستگی: T016. مالک: موتور یادگیری.
  - خروجی: کاندیدا از due/weak skills/error-rule links، سطح، زمان/انرژی و capability؛ استفاده از جملهٔ پذیرفته‌شده و مثال تازه برای همان قاعده؛ anti-repetition با random seed ذخیره‌شده؛ reason code.
  - پذیرش: inputs/clock/seed یکسان برنامهٔ یکسان بدهند؛ تکرار فوریِ پاسخ دیده‌شده مستقل امتیاز نگیرد؛ قابلیت unavailable انتخاب نشود؛ تغییر writing mastery بهبود listening را جعل نکند؛ حالت بدون کاندیدا پایان روشن داشته باشد. rule tags پیشنهادی نامعتبر وارد رتبه‌بندی نشوند.
  - شواهد تکمیل: planner خالص و provider-independent با seed/hash پایدار، clock ورودی، limit، due/unknown/weak/error-rule/fresh-context reason code، فیلتر capability و recently-attempted و allow-list ruleها ساخته شد. projection هر `ReviewUnit` مستقل مصرف می‌شود و هیچ mastery یا schedule را تغییر نمی‌دهد؛ تست deterministic ordering، filtering و reason code پاس شد. planner قدیمی `AdaptiveLearningPlanner` دست‌نخورده و فقط مرز جدید به‌صورت مستقل در Application باقی مانده است.

- [x] T018 [US6] نمایش سابقهٔ جمله و دلیل تمرین در `apps/learner/App/Practice/History/SentenceLearningHistoryView.swift` و کلیدها در `specs/004-adaptive-skill-practice/localization/history.md`.
  - وابستگی: T011، T017. مالک: UI سابقه.
  - پذیرش: کاربر original، اصلاح، نسخهٔ طبیعی، خطا، تمرین‌های بعدی و دلیل انتخاب را ببیند؛ پذیرش/عدم استفاده/ویرایش از use case انجام شود؛ unknown با صفر اشتباه نشود؛ این صفحه دادهٔ ساختگی به progress نفرستد.
  - شواهد تکمیل: history view داده و actionهای use case را تزریق می‌گیرد و مستقیماً به persistence/progress دسترسی ندارد؛ original، minimal correction، natural variant، rule links، next-exercise description و planner reason را نمایش می‌دهد. `unknown` پیام مستقل دارد و score صفر به آن تبدیل نمی‌شود. accept/decline/edit فقط از `SentenceLearningHistoryUseCases` فراخوانی می‌شوند و edit از مسیر revalidation در T016 عبور می‌کند. کلیدهای history در fa/en/de اضافه و JSON validation شد؛ iOS Simulator و macOS Debug build موفق شدند.

- [x] T019 [US6] آزمون چرخهٔ پویا در `packages/LinguaBrainKit/Tests/LinguaBrainApplicationTests/AdaptivePracticeLoopTests.swift` و `apps/learner/Tests/SentenceReuseIntegrationTests.swift`.
  - وابستگی: T015، T018. مالک: آزمون یکپارچگی.
  - پذیرش: writing → accept → restart → grammar/listening exercise descriptor → fresh-context transfer؛ رد correction، revision جدید، replay، حذف و قابلیت خاموش پوشش داده شوند؛ reuse خودِ event قبلی را دوباره امتیاز ندهد. آزمون با fake providers مستقل اجرا شود.
  - شواهد تکمیل: تست package چرخهٔ accept/restart/planner، decline، capability-off و revision replay را با repository file-backed/deterministic پوشش می‌دهد؛ تست app-level در `SentenceReuseIntegrationTests.swift` روی iPhone 17 Simulator restart و انتخاب فقط grammar را اثبات می‌کند و writing capability خاموش را وارد plan نمی‌کند. هیچ event قبلی دوباره نمره‌دهی یا به skill دیگر منتقل نمی‌شود.

این نقطه اولین تحویل «یادگیری پویا» است: نگارش و یادگیری از اصلاح‌ها، با descriptor/preview تمرین‌های آینده. اعلام تکمیل سایر مهارت‌ها تا تست داستان مربوط مجاز نیست.

## فاز ۶ — US3: گرامر در بافت و توضیح کاربرد

آزمون مستقل: جملهٔ دارای یک خطای روشن و سپس `weil` ارائه شود؛ توضیح غیرکتابی اما درست کاربر پذیرفته شود؛ توضیح غلط با صرف نمایش نسخهٔ صحیح امتیاز نگیرد.

- [x] T020 [P] [US3] بانک اولیهٔ قواعد و قالب‌های تمرین در `packages/LinguaBrainKit/Sources/LinguaBrainApplication/Practice/GrammarExerciseFactory.swift` و `specs/004-adaptive-skill-practice/contracts/grammar.md`.
  - وابستگی: T008. مالک: محتوای گرامر.
  - خروجی: قواعد محدود و بررسی‌شدهٔ ترتیب فعل، صرف، article/case و conjunction؛ قالب explain-error و explain-usage با demonstration اختیاری و کمک مرحله‌ای؛ metadata سطح و clean source.
  - پذیرش: prompt ساختگی چندخطایی یا مبهم وارد صف نشود؛ نقش conjunction/preposition دقیق باشد؛ target rule و پاسخ مرجع قابل پیگیری باشد؛ اصلاح/cloze تنها scaffolding باشند و جای توضیح کاربر را نگیرند.

- [x] T021 [US3] ارزیاب توضیح گرامر در `packages/LinguaBrainKit/Sources/LinguaBrainAI/Practice/GrammarEvaluationProvider.swift` و سرویس در `packages/LinguaBrainKit/Sources/LinguaBrainApplication/Practice/GrammarPracticeService.swift`.
  - وابستگی: T020، T013. مالک: Grammar AI/Application.
  - پذیرش: مفهوم توضیح به زبان کاربر سنجیده شود؛ چند بیان معتبر قبول شوند؛ explanation و application نتیجهٔ جدا داشته باشند؛ feedback با rule ID تأییدشده مرتبط باشد؛ خطای سرویس ungraded بماند؛ پیشنهاد AI مستقیماً rule canonical نسازد.
  - شواهد تکمیل: provider اکنون مستقیماً `PracticeEvaluator` است و rule را فقط از بانک canonical با `ReviewUnit.objectiveKey` resolve می‌کند؛ rule ناشناخته یا rule ID پیشنهادی متفاوت رد می‌شود. explanation و application در دو `TypedFeedback` مستقل حفظ می‌شوند، partial بدون تبدیل باقی می‌ماند و transport/cancellation/low-confidence از مسیر ungraded جلسه عبور می‌کنند. چهار تست package، عبارت معتبر متفاوت، partial، جداسازی feedback، rule جعلی، کم‌اطمینانی و cancellation را پوشش می‌دهند؛ evaluator هیچ mutation روی rule/mastery/schedule ندارد.

- [x] T022 [US3] صفحهٔ گرامر در `apps/learner/App/Practice/Grammar/GrammarPracticeView.swift` و کلیدها در `specs/004-adaptive-skill-practice/localization/grammar.md`.
  - وابستگی: T011، T021. مالک: UI گرامر.
  - پذیرش: تشخیص خطا/توضیح کاربرد از prompt مشخص باشد؛ فضای توضیح و مثال از هم قابل تشخیص؛ rule hint، reveal دلیل و نسخهٔ صحیح، retry و next کار کنند؛ جمله/معنی هر کدام جهت مستقل داشته باشند.
  - شواهد تکمیل: view از mode برای instruction مستقل explain-error/explain-usage استفاده می‌کند، prompt، demonstration، rule ID و TextEditor توضیح را جدا نمایش می‌دهد و reference answer فقط از policy مشترک feedback/reveal قابل مشاهده است. retry/continue/hint/reveal از scaffold intent-only مشترک می‌آیند و جهت answer با language tag مستقل است. فایل در هر دو app target build شد و `GrammarPracticeTests.swift` به test target افزوده شد؛ اجرای runner در این نوبت به‌علت hang شبیه‌ساز نهایی نشد، بنابراین T023 باز مانده است.

- [x] T023 [US3] آزمون گرامر در `packages/LinguaBrainKit/Tests/LinguaBrainAITests/GrammarEvaluationTests.swift` و `apps/learner/Tests/GrammarPracticeTests.swift`.
  - وابستگی: T022. مالک: QA گرامر.
  - پذیرش: توضیح درست با عبارت متفاوت، توضیح اشتباه، جملهٔ صحیح بدون خطا، prompt مبهم، declined evaluation و پیوند error به تمرین آینده بررسی شوند؛ روی قرارداد ثابت خروجی مدل fake تست شود و کیفیت زبانی نمونه‌ها جدا ثبت شود.
  - شواهد تکمیل: چهار تست AI با transport fake عبارت معتبر متفاوت، partial، feedback دو‌بخشی، rule جعلی، low-confidence و cancellation را بررسی می‌کنند؛ تست‌های factory prompt مبهم/چندخطایی/منبع نامعتبر و قالب جملهٔ صحیح را رد یا حفظ می‌کنند و planner tests پیوند rule error به تمرین آینده را پوشش می‌دهند. دو تست app-level جدایی prompt/example/explanation، hidden reference و جهت مستقل de/fa را روی iPhone 17 Simulator اجرا کردند. اجرای 2026-09-08 با شش تست مرتبط بدون failure پایان یافت.

## فاز ۷ — US4: درک معنایی جملهٔ شنیده‌شده

آزمون مستقل: جمله با نفی/زمان روشن پخش شود؛ بازگویی معنایی درست پذیرفته و معکوس‌کردن نفی توضیح داده شود؛ متن و ترجمهٔ دقیق همان صوت پس از feedback دیده شوند.

- [x] T024 [P] [US4] سرویس صوت جمله در `packages/LinguaBrainKit/Sources/LinguaBrainMedia/Practice/SentenceAudioService.swift` و adapter سیستم در `apps/learner/App/Practice/Audio/AppleSentencePlayback.swift`.
  - وابستگی: T008. مالک: Media.
  - خروجی: cache key از sentence/revision/text hash/language/voice/model؛ cached/TTS capability؛ play/replay/slow/stop؛ خطا و missing audio صریح.
  - پذیرش: صدای واژه هرگز جای جمله پخش نشود؛ متن عوض‌شده از audio قبلی استفاده نکند؛ next/exit صدای قبلی را متوقف کند؛ locale و سرعت معتبر باشند؛ Apple API با SDK 27 بررسی شود؛ نبود جمله به fallback گمراه‌کنندهٔ تک‌واژه منجر نشود.
  - شواهد تکمیل: cache key سرویس شامل sentence ID/revision/text hash/language/voice/model است و تست دو revision را به دو generation جدا و تکرار همان revision را به cache hit تبدیل می‌کند؛ sentence غایب error صریح دارد و word-audio fallback وجود ندارد. `AppleSentencePlayback` در app boundary از `AVSpeechSynthesizer` Xcode 27 استفاده می‌کند، locale/voice و slow rate را validate می‌کند، پیش از replay صدای قبلی را متوقف می‌کند و `stop()` برای next/exit دارد. declaration محلی SDK و مستندات رسمی Apple بررسی شد؛ فایل در هر دو app target است و iOS Simulator Debug build پاس شد.

- [x] T025 [US4] rubric و ارزیابی معنایی در `specs/004-adaptive-skill-practice/contracts/listening.md`، `packages/LinguaBrainKit/Sources/LinguaBrainAI/Practice/ListeningEvaluationProvider.swift` و `packages/LinguaBrainKit/Sources/LinguaBrainApplication/Practice/ListeningPracticeService.swift`.
  - وابستگی: T013، T024. مالک: Listening AI/Application.
  - پذیرش: معنای جمله ملاک باشد، نه `acceptedMeanings` واژه؛ عامل/عمل/نفی/عدد/زمان مرتبط سنجیده شوند؛ paraphrase و partial فهم با توضیح مناسب؛ املا و نگارش زبان مادری بی‌جهت نمرهٔ درک را پایین نیاورد؛ uncertainty/unavailable حفظ شود.
  - شواهد تکمیل: قرارداد semantic slotهای agent/patient/action/negation/number/time/modality و رفتار correct/partial/incorrect را تعریف می‌کند و orthography زبان پاسخ را از comprehension جدا می‌سازد. provider دیگر prompt را transcript فرض نمی‌کند؛ context resolver تزریق‌شده باید sentence ID/revision، ترجمهٔ بازبینی‌شده و checksum صوت پخش‌شده را تطبیق دهد. mismatch، cancellation و low confidence ungraded هستند و partial حفظ می‌شود. پنج تست package این boundaryها را بدون network/credential/live data پوشش دادند.

- [x] T026 [US4] صفحهٔ شنیداری در `apps/learner/App/Practice/Listening/ListeningPracticeView.swift` و کلیدها در `specs/004-adaptive-skill-practice/localization/listening.md`.
  - وابستگی: T011، T025. مالک: UI شنیداری.
  - پذیرش: پیش از submit/reveal متن و ترجمه در UI و accessibility tree لو نرود؛ پس از نتیجهٔ ارزیابی جمله و ترجمهٔ همان revision خودکار ظاهر شوند؛ هنگام خطای سرویس reveal/next قابل استفاده؛ منبع معنی، ترجمهٔ sentence باشد نه معنی واژه؛ replay/slow و ورودی چندخطی فراهم باشد.
  - شواهد تکمیل: view فقط کنترل‌های replay/slow و ورودی چندخطی را پیش از نتیجه می‌سازد؛ transcript/translation همان `Sentence` تنها از visibility policy مشترک در feedback یا reveal وارد view می‌شود. unavailable همچنان reveal/continue scaffold را دارد، خروج صفحه model و playback را لغو/متوقف می‌کند، و replay labels در fa/en/de موجود است. تست hidden-content روی iPhone 17 Simulator پاس شد و تست visibility policy برای answering/feedback/revealed/unavailable افزوده شد؛ iOS Simulator build پاس است. QA سناریوهای کامل صوت در T027 باز می‌ماند.

- [ ] T027 [US4] آزمون شنیداری در `packages/LinguaBrainKit/Tests/LinguaBrainAITests/ListeningEvaluationTests.swift` و `apps/learner/Tests/ListeningPracticeTests.swift`.
  - وابستگی: T026. مالک: QA شنیداری.
  - پذیرش: paraphrase، نفی معکوس، عامل اشتباه، درک جزئی، sentence/audio mismatch، hide/reveal، لغو، دو بار پخش، unavailable و بازیابی پس از restart تست شوند؛ هم‌خوانی صوت و متن با sample واقعی بررسی شود.

## فاز ۸ — US5: تکرار جمله و ارزیابی واقعی تلفظ

آزمون مستقل: صوت مصنوعی/دارای مجوزِ جملهٔ مشخص به ارزیاب داده شود؛ خروجی با معیار مرجع T028 سنجیده شود؛ سپس روی دستگاه ضبط و بازپخش آزمایش شود. متن transcript به‌تنهایی ورودی معتبر نمره‌دهی نیست.

- [x] T028 [P] [US5] پژوهش قابلیت و معیار پذیرش تلفظ در `specs/004-adaptive-skill-practice/research-pronunciation.md` و `specs/004-adaptive-skill-practice/contracts/pronunciation.md`.
  - وابستگی: T002؛ می‌تواند هم‌زمان با T003 و مراحل بعد آغاز شود. مالک: متخصص صوت.
  - خروجی: بررسی منابع رسمی فعلی و تست امکان‌سنجی provider قابل‌تعویض برای آلمانی؛ ورودی audio+reference، دانه‌بندی خروجی، confidence، score scale، کیفیت/latency/cost، مجوز fixtures؛ انتخاب یا رد مستدل قابلیت.
  - پذیرش: rubric و حدهای پذیرش عددی روی benchmark بازبینی‌شده پیش از فعال‌سازی نمره تعیین شوند؛ خواندن درست، خطای هدفمند، سکوت/نویز/کلیپ و اختلاف گوینده پوشش داده شود. هیچ سرویس صرفاً transcription به‌عنوان pronunciation معرفی نشود. عدم دستیابی به capability، T030–T032 را باز نگه می‌دارد؛ خرید/ارسال ضبط خصوصی ضمنی مجاز نیست.
  - شواهد تکمیل: پژوهش 2026-09-07 نتیجهٔ صریح «هیچ provider ارزیابی تلفظ برای production تأیید نشده» را ثبت کرده و transcription similarity را از pronunciation score جدا می‌کند. قرارداد `pronunciation-evidence-v1` ورودی صوت واقعی، sentence revision/checksum، consent، provenance، confidence و مسیرهای silence/noise/clipping/cancellation/unsupported را الزام می‌کند. benchmark gate شامل correct reading، targeted errors، silence/noise/clipping و speaker variation با آستانه‌های 90%/80% و confidence حداقل 0.75 مستند است. این نتیجهٔ منفی طبق acceptance معتبر است و T030–T032 را عمداً باز نگه می‌دارد.

- [ ] T029 [US5] ضبط و بازپخش پاسخ در `apps/learner/App/Practice/Audio/ApplePracticeRecorder.swift` و `apps/learner/Tests/PracticeRecorderTests.swift`.
  - وابستگی: T008، T024، T028. مالک: Apple Audio.
  - پذیرش: permission flow، فایل/بافر با metadata دقیق، duration limit، input quality، interruption/route change، stop-finalize واقعی، cancel/cleanup و بازپخش خود کاربر؛ sleep ثابت برای حدس پایان transcript وجود نداشته باشد؛ خروج از صفحه ضبط را متوقف کند؛ recording پیش‌فرض موقتی و نگهداری طولانی opt-in باشد.

- [ ] T030 [US5] adapter و سرویس تلفظ در `packages/LinguaBrainKit/Sources/LinguaBrainMedia/Practice/PronunciationAssessmentAdapter.swift` و `packages/LinguaBrainKit/Sources/LinguaBrainApplication/Practice/SpeakingPracticeService.swift`.
  - وابستگی: T029 و نتیجهٔ مثبت T028. مالک: ارزیاب صوت.
  - پذیرش: audio واقعی+reference revision پردازش شود؛ نتیجه طبق scale/version مصوب normalize شود؛ word/sound span و confidence validate شوند؛ noise/low confidence ungradable باشد؛ rhythm/fluency فقط در صورت قابلیت آزموده‌شده؛ Provider هیچ state آموزشی را مستقیم تغییر ندهد.

- [ ] T031 [US5] صفحهٔ تکرار جمله در `apps/learner/App/Practice/Speaking/SpeakingPracticeView.swift` و کلیدها در `specs/004-adaptive-skill-practice/localization/speaking.md`.
  - وابستگی: T011، T030. مالک: UI گفتار.
  - پذیرش: متن و صوت مرجع، ضبط، بازپخش خود، نمره با توضیح، کلمات مشکل‌دار و تمرین مجدد فراهم باشد؛ مثال راهنمای اصلاح قابل شنیدن باشد؛ بدون capability عدد ساختگی یا success تولید نشود؛ retry روی کلمه و کل جمله قابل تفکیک باشد؛ دسترسی denied مسیر قابل فهم داشته باشد.

- [ ] T032 [US5] اعتبارسنجی امتیاز و دستگاه در `apps/learner/Tests/SpeakingPracticeTests.swift` و `specs/004-adaptive-skill-practice/verification-pronunciation.md`.
  - وابستگی: T031. مالک: QA صوت.
  - پذیرش: benchmark و حدهای T028 پاس شوند؛ Mac و iPhone فیزیکی، مجوز، میکروفون، اختلال، retry، cancellation و cleanup بررسی شوند؛ شواهد زبان/مدل/نسخه/scale ثبت شوند. نبود دستگاه یا Provider را pending ثبت کنید؛ build و fake test به‌تنهایی جای این gate نیستند.

## فاز ۹ — ادغام و تحویل قابل اعتماد

- [ ] T033 یکپارچه‌سازی مسیرهای برنامه و زبان‌ها در `apps/learner/App/TodayPrototypeView.swift`، `apps/learner/App/ProgressPrototypeView.swift`، `apps/learner/App/PrototypeRootView.swift`، `apps/learner/App/Practice/PracticeComposition.swift`، `apps/learner/Resources/Localization/fa.json`، `apps/learner/Resources/Localization/en.json`، `apps/learner/Resources/Localization/de.json` و `apps/learner/Resources/Localizable.xcstrings`.
  - وابستگی: T019، T023، T027؛ گفتار هنگام تکمیل T032. مالک: تنها هماهنگ‌کننده.
  - پذیرش: navigation از Today و weak-skill recommendations به تمرین درست برسد؛ «مرور پیشنهادی» همچنان فقط صف کارت‌های موعددار Anki باشد و هیچ تمرین چهارمهارتی را مخلوط/جایگزین نکند؛ progress از evidence واقعی خوانده شود؛ mode unavailable صریح gated باشد؛ کلیدهای داستان‌ها یک بار merge شوند؛ فایل‌ها در هر دو app target حاضر باشند. ادغام مرحله‌ای مجاز است؛ checkbox نهایی پس از تمام داستان‌ها.
  - وضعیت (۲۰۲۶-۱۰-۱۳): فازهای A1 (لایهٔ package) و A2 (اتصال به برنامه) در [طرح یکپارچه‌سازی T033](T033-integration-design.md) پیاده‌سازی شده‌اند: مسیر Today به تمرین نوشتن و شنیداری، توضیح صریح برای حالت‌های در دسترس نبودن، پیشنهاد ضعیف‌ترین مهارت و پیشرفت از GRDB. این تسک تا آماده شدن محتوای بررسی‌شدهٔ دستور زبان، build در Xcode 27 و QA روی دستگاه باز می‌ماند.

- [ ] T034 مالکیت، حذف و خروجی داده‌های تمرین را در `packages/LinguaBrainKit/Sources/LinguaBrainApplication/Practice/PracticeDataOwnershipService.swift`، `apps/learner/App/Practice/History/SentenceLearningHistoryView.swift` و `packages/LinguaBrainKit/Tests/LinguaBrainApplicationTests/PracticeDataOwnershipTests.swift` تکمیل کنید.
  - وابستگی: T018، T029، T030. مالک: Data ownership.
  - پذیرش: export اصلی کاربر جمله/نسخه/تلاش/بازخورد قابل‌فهم داشته باشد؛ حذف خصوصی cache/audio و projection مربوط را طبق contract هماهنگ کند؛ تاریخچهٔ unrelated دست‌نخورده بماند؛ append-only بودن رویدادها مانع حذف صریح دادهٔ کاربر نشود؛ consent لغوشده درخواست جدید نفرستد. sync ضبط‌ها و ساخت APKG جدید در محدوده نیست.

- [ ] T035 اجرای QA نهایی در `specs/004-adaptive-skill-practice/verification.md` و آزمون‌های UI در `apps/learner/Tests/AdaptivePracticeJourneyTests.swift`.
  - وابستگی: T033، T034. مالک: QA یکپارچه.
  - پذیرش: package tests و build هر دو scheme؛ iPhone/iPad/Mac با RTL/LTR، فونت بزرگ، keyboard، VoiceOver، narrow window، offline، no provider، resume و re-import قبلی؛ flow writing→reuse→grammar/listening→speaking ثبت شود. وقت/موعد مهارت‌ها مستقل بماند؛ نتیجهٔ ناکامل یا تست action غایب صریح گزارش شود.

- [ ] T036 بستن traceability و گزارش تحویل در `specs/004-adaptive-skill-practice/tasks.md`، `specs/004-adaptive-skill-practice/spec.md`، `specs/004-adaptive-skill-practice/plan.md`، `PROJECT_STATUS.md` و `CHANGELOG.md`.
  - وابستگی: T035. مالک: هماهنگ‌کننده.
  - پذیرش: هر checkbox سند شواهد داشته باشد؛ تسک‌های قدیمی فقط به نسبت coverage واقعی بسته شوند؛ تصمیم‌ها و workaroundهای beta ثبت شوند؛ محدودیت provider/تلفظ پنهان نشود؛ diff بدون فایل صوت خصوصی/کلید/دیتابیس/تغییر نامرتبط باشد. implementation ناتمام را با عباراتی مثل «زیرساخت آماده شد» کامل اعلام نکنید.

## وابستگی و ترتیب واگذاری

| بسته | تسک‌ها | پیش‌نیاز تحویل بسته |
| --- | --- | --- |
| A: قرارداد و هسته | T001–T008 | شروع از T001؛ هر تسک طبق زنجیرهٔ بالا |
| B: رابط مشترک | T009–T011 | A |
| C: نگارش | T012–T015 | backend از A؛ صفحه بعد از B |
| D: یادگیری پویا | T016–T019 | backend نگارش؛ UI بعد از B |
| E: گرامر | T020–T023 | A، decoder متنی T013، پوسته B |
| F: شنیداری | T024–T027 | A، decoder T013، پوسته B |
| G: گفتار | T028–T032 | پژوهش بعد از T002؛ اجرا پس از A، F/T024 و نتیجهٔ پژوهش |
| H: ادغام/مالکیت/QA | T033–T036 | طبق وابستگی هر تسک؛ بستن نهایی بعد از همهٔ داستان‌ها |

ترتیب پیشنهادی برای یک توسعه‌دهنده: A → B → C → D → E → F → G → H. پژوهش T028 را زود آغاز کنید تا محدودیت provider در پایان پروژه غافلگیر نکند.

### نمونه‌های اجرای موازی با مالکیت مستقل

- بعد از T002: T028 پژوهش صوت کنار T003 مدل‌ها؛ فایل مشترک ندارند.
- بعد از A: T009 پوسته، T012 rubric نگارش، T020 محتوای گرامر و T024 صوت جمله قابل تقسیم‌اند.
- بعد از T013: T014 سرویس نگارش، T021 گرامر و T025 شنیداری در فایل‌های اختصاصی؛ decoder مشترک فقط یک مالک دارد. تغییر قرارداد مشترک باید پیش از ادغام هماهنگ شود.
- بعد از T016/T011: UI داستان‌ها براساس service fake قابل توسعه است؛ شرط پذیرش هر task اتصال واقعی است. T018 و T034 هر دو History View را لمس می‌کنند، بنابراین ویرایش آن فایل ترتیبی انجام شود.
- پژوهش/آزمون هر داستان را می‌توان مستقل آماده کرد، ولی checkbox تست تنها پس از اجرای نسخهٔ واقعی بسته می‌شود. برای US6 آزمون مستقل T019 جای دورزدن پیش‌نیاز T015 را نمی‌گیرد.

## تعریف اولین تحویل و پایان کل کار

اولین تحویل کم‌ریسک: T001–T019؛ کاربر جمله می‌نویسد، اصلاح را می‌پذیرد، داده پس از restart حفظ می‌شود و برنامهٔ آینده از خطای واقعی او ساخته می‌شود. تولید descriptor تمرین آینده جای پیاده‌سازی UI سایر مهارت‌ها را نمی‌گیرد.

پایان کل درخواست: T001–T036 با شواهد؛ تلفظ واقعی بدون T028/T032 کامل نیست. تعداد تسک‌ها: ۳۶؛ Setup/Foundation: ۸؛ US1: ۳؛ US2: ۴؛ US6: ۴؛ US3: ۴؛ US4: ۴؛ US5: ۵؛ ادغام نهایی: ۴.
