// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get navHome => 'Início';

  @override
  String get navExercises => 'Exercícios';

  @override
  String get navRoutines => 'Rotinas';

  @override
  String get navProfile => 'Perfil';

  @override
  String get sagaTabLabel => 'Saga';

  @override
  String get classSlotPlaceholder => 'O ferro lhe dará um nome.';

  @override
  String get dormantCardioCopy =>
      'As runas de cardio despertam em um capítulo futuro.';

  @override
  String get firstSetAwakensCopy => 'Sua primeira série desperta este caminho.';

  @override
  String get statsDeepDiveLabel => 'Estatísticas';

  @override
  String get titlesLabel => 'Títulos';

  @override
  String get historyLabel => 'Histórico';

  @override
  String get comingSoonStub => 'Em breve.';

  @override
  String get settingsLabel => 'Configurações';

  @override
  String get save => 'Salvar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Excluir';

  @override
  String get confirm => 'Confirmar';

  @override
  String get retry => 'Tentar novamente';

  @override
  String get dismiss => 'Dispensar';

  @override
  String get continueLabel => 'Continuar';

  @override
  String get logOut => 'Sair';

  @override
  String get done => 'Concluir';

  @override
  String get edit => 'Editar';

  @override
  String get create => 'Criar';

  @override
  String get add => 'Adicionar';

  @override
  String get skip => 'Pular';

  @override
  String get back => 'Voltar';

  @override
  String get close => 'Fechar';

  @override
  String get start => 'Iniciar';

  @override
  String get remove => 'Remover';

  @override
  String get discard => 'Descartar';

  @override
  String get resume => 'Retomar';

  @override
  String get clear => 'Limpar';

  @override
  String get replace => 'Substituir';

  @override
  String get undo => 'Desfazer';

  @override
  String get all => 'Todos';

  @override
  String get or => 'OU';

  @override
  String get loading => 'Carregando...';

  @override
  String get error => 'Algo deu errado';

  @override
  String get noResults => 'Nenhum resultado encontrado';

  @override
  String get emptyState => 'Nada aqui ainda';

  @override
  String get search => 'Buscar';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Senha';

  @override
  String get logIn => 'ENTRAR';

  @override
  String get signUp => 'CADASTRAR';

  @override
  String get forgotPassword => 'Esqueceu a senha?';

  @override
  String get sendResetEmail => 'Enviar E-mail de Recuperação';

  @override
  String get offlineBanner =>
      'Offline — alterações serão sincronizadas quando você voltar a ficar online';

  @override
  String pendingSyncSingular(int count) {
    return '$count alteração pendente';
  }

  @override
  String pendingSyncPlural(int count) {
    return '$count alterações pendentes';
  }

  @override
  String get today => 'Hoje';

  @override
  String get yesterday => 'Ontem';

  @override
  String daysAgo(int count) {
    return '$count dias atrás';
  }

  @override
  String weeksAgo(int count) {
    return '$count semanas atrás';
  }

  @override
  String monthsAgo(int count) {
    return '$count meses atrás';
  }

  @override
  String get muscleGroupChest => 'Peito';

  @override
  String get muscleGroupBack => 'Costas';

  @override
  String get muscleGroupLegs => 'Pernas';

  @override
  String get muscleGroupShoulders => 'Ombros';

  @override
  String get muscleGroupArms => 'Braços';

  @override
  String get muscleGroupCore => 'Core';

  @override
  String get muscleGroupCardio => 'Cardio';

  @override
  String get equipmentBarbell => 'Barra';

  @override
  String get equipmentDumbbell => 'Halter';

  @override
  String get equipmentCable => 'Cabo';

  @override
  String get equipmentMachine => 'Máquina';

  @override
  String get equipmentBodyweight => 'Peso Corporal';

  @override
  String get equipmentBands => 'Bands';

  @override
  String get equipmentKettlebell => 'Kettlebell';

  @override
  String get setTypeWorking => 'Normal';

  @override
  String get setTypeWarmup => 'Aquecimento';

  @override
  String get setTypeDropset => 'Drop Set';

  @override
  String get setTypeFailure => 'Até a Falha';

  @override
  String get recordTypeMaxWeight => 'Peso Máximo';

  @override
  String get recordTypeMaxReps => 'Reps Máximo';

  @override
  String get recordTypeMaxVolume => 'Volume Máximo';

  @override
  String get weightUnitKg => 'KG';

  @override
  String get weightUnitLbs => 'LBS';

  @override
  String get appName => 'RepSaga';

  @override
  String get welcomeBack => 'Bem-vindo de volta';

  @override
  String get createYourAccount => 'Crie sua conta';

  @override
  String get emailRequired => 'E-mail é obrigatório';

  @override
  String get emailInvalid => 'Insira um e-mail válido';

  @override
  String get passwordRequired => 'Senha é obrigatória';

  @override
  String get passwordTooShort => 'A senha deve ter pelo menos 6 caracteres';

  @override
  String get forgotPasswordHint =>
      'Digite seu e-mail acima e toque em \"Esqueceu a senha?\"';

  @override
  String get resetPassword => 'Redefinir Senha';

  @override
  String sendResetEmailTo(String email) {
    return 'Enviar e-mail de redefinição de senha para $email?';
  }

  @override
  String get resetEmailSent =>
      'E-mail de redefinição enviado. Verifique sua caixa de entrada.';

  @override
  String get continueWithGoogle => 'Continuar com Google';

  @override
  String get alreadyHaveAccount => 'Já tem uma conta? Entrar';

  @override
  String get dontHaveAccount => 'Não tem uma conta? Cadastrar';

  @override
  String get legalAgreePrefix => 'Ao continuar, você concorda com nossos ';

  @override
  String get termsOfService => 'Termos de Serviço';

  @override
  String get andSeparator => ' e ';

  @override
  String get privacyPolicy => 'Política de Privacidade';

  @override
  String get authErrorInvalidCredentials =>
      'E-mail ou senha incorretos. Tente novamente.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Verifique sua caixa de entrada e confirme seu e-mail primeiro.';

  @override
  String get authErrorAlreadyRegistered =>
      'Uma conta com este e-mail já existe. Tente entrar.';

  @override
  String get authErrorRateLimit =>
      'Muitas tentativas. Aguarde um momento e tente novamente.';

  @override
  String get authErrorWeakPassword =>
      'A senha é muito fraca. Use pelo menos 6 caracteres.';

  @override
  String get authErrorNetwork =>
      'Sem conexão com a internet. Verifique sua rede e tente novamente.';

  @override
  String get authErrorTimeout => 'A solicitação expirou. Tente novamente.';

  @override
  String get authErrorTokenExpired =>
      'O link de confirmação expirou. Solicite um novo.';

  @override
  String get authErrorGeneric => 'Algo deu errado. Tente novamente.';

  @override
  String get checkYourInbox => 'Verifique sua caixa de entrada';

  @override
  String get confirmationSentTo => 'Enviamos um e-mail de confirmação para';

  @override
  String get confirmationSent => 'Enviamos um e-mail de confirmação';

  @override
  String get tapLinkToVerify =>
      'Toque no link do e-mail para verificar sua conta, depois volte e faça login.';

  @override
  String get emailResent => 'E-mail reenviado! Verifique sua caixa de entrada.';

  @override
  String get backToLogin => 'VOLTAR PARA LOGIN';

  @override
  String get didntReceiveResend => 'Não recebeu? Reenviar e-mail';

  @override
  String get onboardingHeadline => 'Registre cada rep,\nsempre';

  @override
  String get onboardingSubtitle =>
      'Registre treinos, quebre recordes pessoais e construa o físico que você deseja.';

  @override
  String get getStarted => 'COMEÇAR';

  @override
  String get setupProfile => 'Configure seu perfil';

  @override
  String get tellUsAboutYourself => 'Conte um pouco sobre você';

  @override
  String get displayName => 'Nome de exibição';

  @override
  String get fitnessLevel => 'Nível de condicionamento';

  @override
  String get howOftenTrain => 'Com que frequência você planeja treinar?';

  @override
  String get weeklyGoalHint =>
      'Sua meta semanal — você pode alterar a qualquer momento';

  @override
  String get letsGo => 'VAMOS LÁ';

  @override
  String get pleaseEnterName => 'Por favor, insira seu nome.';

  @override
  String get failedToSaveProfile => 'Falha ao salvar perfil. Tente novamente.';

  @override
  String get fitnessLevelBeginner => 'Iniciante';

  @override
  String get fitnessLevelIntermediate => 'Intermediário';

  @override
  String get fitnessLevelAdvanced => 'Avançado';

  @override
  String homeStatusWeekComplete(int count) {
    return 'Semana completa — $count de $count concluídos';
  }

  @override
  String homeStatusProgress(int total) {
    return ' de $total esta semana';
  }

  @override
  String get noPlanThisWeek => 'Sem plano esta semana';

  @override
  String get samePlanThisWeek => 'Mesmo plano esta semana?';

  @override
  String get myRoutines => 'MINHAS ROTINAS';

  @override
  String get seeAll => 'Ver tudo';

  @override
  String get createYourFirstRoutine => 'Crie Sua Primeira Rotina';

  @override
  String get heroUpNext => 'PRÓXIMO';

  @override
  String get heroYourFirstWorkout => 'SEU PRIMEIRO TREINO';

  @override
  String get heroNoPlan => 'SEM PLANO';

  @override
  String get heroNewWeek => 'NOVA SEMANA';

  @override
  String get planYourWeek => 'Planeje sua semana';

  @override
  String get pickRoutinesForWeek => 'Escolha rotinas para a semana';

  @override
  String get quickWorkout => 'Treino rápido';

  @override
  String get startNewWeek => 'Começar nova semana';

  @override
  String nOfNDone(int completed, int total) {
    return '$completed de $total concluídos';
  }

  @override
  String exerciseCountDuration(int count, int minutes) {
    return '$count exercícios · ~$minutes min';
  }

  @override
  String get offlineStartWorkout =>
      'Iniciar um treino requer conexão com a internet';

  @override
  String get couldNotLoadExercises =>
      'Não foi possível carregar exercícios. Tente novamente.';

  @override
  String get lastSessionPrefix => 'Último: ';

  @override
  String get exercises => 'Exercícios';

  @override
  String get searchExercises => 'Buscar exercícios...';

  @override
  String get noExercisesMatchFilters =>
      'Nenhum exercício corresponde aos filtros';

  @override
  String get yourExercisesWillAppear => 'Seus exercícios aparecerão aqui';

  @override
  String get clearFilters => 'Limpar Filtros';

  @override
  String get createExercise => 'Criar Exercício';

  @override
  String get exerciseDetails => 'Detalhes do Exercício';

  @override
  String get failedToLoadExercise => 'Falha ao carregar exercício';

  @override
  String get customExercise => 'Exercício personalizado';

  @override
  String get personalRecords => 'Recordes Pessoais';

  @override
  String get noRecordsYet => 'Nenhum recorde ainda';

  @override
  String get deleteExercise => 'Excluir Exercício';

  @override
  String deleteExerciseConfirm(String name) {
    return 'Tem certeza que deseja excluir \"$name\"?';
  }

  @override
  String get deleting => 'Excluindo...';

  @override
  String get imageStart => 'Início';

  @override
  String get imageEnd => 'Fim';

  @override
  String repsUnit(int count) {
    return '$count reps';
  }

  @override
  String get exerciseName => 'Nome do Exercício';

  @override
  String get nameRequired => 'Nome é obrigatório';

  @override
  String get nameTooShort => 'O nome deve ter pelo menos 2 caracteres';

  @override
  String get muscleGroup => 'Grupo Muscular';

  @override
  String get equipmentType => 'Tipo de Equipamento';

  @override
  String get selectMuscleAndEquipment =>
      'Selecione um grupo muscular e tipo de equipamento';

  @override
  String get sessionExpired => 'Sessão expirada. Faça login novamente.';

  @override
  String get exerciseCreated => 'Exercício criado com sucesso';

  @override
  String get createExerciseButton => 'CRIAR EXERCÍCIO';

  @override
  String get description => 'Descrição';

  @override
  String get descriptionHint => 'Breve descrição do exercício (opcional)';

  @override
  String get formTips => 'Dicas de Forma';

  @override
  String get formTipsHint => 'Dicas de execução, uma por linha (opcional)';

  @override
  String get formTipsHelper => 'Insira cada dica em uma nova linha';

  @override
  String get aboutSection => 'SOBRE';

  @override
  String get formTipsSection => 'DICAS DE FORMA';

  @override
  String get finishWorkout => 'Finalizar Treino';

  @override
  String get completeOneSet => 'Complete pelo menos uma série para finalizar';

  @override
  String get addFirstExercise => 'Adicione seu primeiro exercício';

  @override
  String get tapButtonToStart => 'Toque no botão abaixo para começar';

  @override
  String get addExercise => 'Adicionar Exercício';

  @override
  String get addSet => 'Adicionar Série';

  @override
  String get fillRemaining => 'Preencher restantes';

  @override
  String get filledRemainingSets => 'Séries restantes preenchidas';

  @override
  String get removeExerciseTitle => 'Remover Exercício?';

  @override
  String removeExerciseContent(String name) {
    return 'Remover $name e todas as suas séries?';
  }

  @override
  String get failedToDiscardWorkout =>
      'Falha ao descartar treino. Tente novamente.';

  @override
  String get failedToSaveWorkout => 'Falha ao salvar treino. Tente novamente.';

  @override
  String get workoutSavedOffline =>
      'Treino salvo. Será sincronizado quando voltar a ficar online.';

  @override
  String get setColumnSet => 'SÉRIE';

  @override
  String get setColumnWeight => 'PESO';

  @override
  String get setColumnReps => 'REPS';

  @override
  String get setColumnType => 'TIPO';

  @override
  String setDeleted(int number) {
    return 'Série $number excluída';
  }

  @override
  String previousSet(String weight, String unit, int reps) {
    return 'Anterior: $weight$unit × $reps';
  }

  @override
  String get discardWorkoutTitle => 'Descartar Treino?';

  @override
  String discardWorkoutContent(String duration) {
    return 'Você está treinando há $duration. Esta ação não pode ser desfeita.';
  }

  @override
  String get finishWorkoutTitle => 'Finalizar Treino?';

  @override
  String incompleteSetsWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Você tem $count séries incompletas',
      one: 'Você tem 1 série incompleta',
    );
    return '$_temp0';
  }

  @override
  String get addNotesHint => 'Adicionar notas (opcional)';

  @override
  String get keepGoing => 'Continuar Treinando';

  @override
  String get saveAndFinish => 'Salvar e Finalizar';

  @override
  String get resumeWorkoutTitle => 'Retomar treino?';

  @override
  String get resumeWorkoutStaleTitle => 'Continuar de onde parou?';

  @override
  String workoutInProgress(String name) {
    return '\"$name\" ainda está em andamento.';
  }

  @override
  String workoutInterrupted(String age) {
    return 'foi interrompido $age.';
  }

  @override
  String get resumeAnyway => 'Retomar mesmo assim';

  @override
  String get restTimerLabel => 'Descanso';

  @override
  String restTimerRemaining(String time) {
    return 'Descanso: $time restante';
  }

  @override
  String get subtract30Semantics => 'Subtrair 30 segundos';

  @override
  String get add30Semantics => 'Adicionar 30 segundos';

  @override
  String get skipRestSemantics => 'Pular descanso';

  @override
  String get tapToDismiss => 'Toque em qualquer lugar para fechar';

  @override
  String get lessThanAnHourAgo => 'há menos de uma hora';

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count horas',
      one: 'há 1 hora',
    );
    return '$_temp0';
  }

  @override
  String yesterdayAt(String time) {
    return 'ontem às $time';
  }

  @override
  String weekdayAt(String weekday, String time) {
    return '$weekday às $time';
  }

  @override
  String get history => 'Histórico';

  @override
  String get failedToLoadHistory => 'Falha ao carregar histórico';

  @override
  String get noWorkoutsYet => 'Nenhum treino ainda';

  @override
  String get completedWorkoutsAppear =>
      'Seus treinos concluídos aparecerão aqui';

  @override
  String get startFirstWorkout => 'Comece seu primeiro treino';

  @override
  String get failedToLoadWorkout => 'Falha ao carregar treino';

  @override
  String get workout => 'Treino';

  @override
  String get exerciseGeneric => 'Exercício';

  @override
  String get notes => 'Notas';

  @override
  String totalVolume(String volume) {
    return 'Volume Total: $volume';
  }

  @override
  String get routines => 'Rotinas';

  @override
  String get failedToLoadRoutines => 'Falha ao carregar rotinas';

  @override
  String get myRoutinesSection => 'MINHAS ROTINAS';

  @override
  String get starterRoutinesSection => 'ROTINAS INICIAIS';

  @override
  String get noCustomRoutines =>
      'Nenhuma rotina personalizada ainda. Toque em + para criar.';

  @override
  String get createRoutine => 'Criar Rotina';

  @override
  String get editRoutine => 'Editar Rotina';

  @override
  String get routineName => 'Nome da rotina';

  @override
  String get failedToSaveRoutine => 'Falha ao salvar rotina. Tente novamente.';

  @override
  String get setsLabel => 'Séries';

  @override
  String get restLabel => 'Descanso';

  @override
  String get duplicateAndEdit => 'Duplicar e Editar';

  @override
  String get deleteRoutine => 'Excluir Rotina';

  @override
  String deleteRoutineConfirm(String name) {
    return 'Excluir \"$name\"? Esta ação não pode ser desfeita.';
  }

  @override
  String exercisesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exercícios',
      one: '1 exercício',
    );
    return '$_temp0';
  }

  @override
  String get profile => 'Perfil';

  @override
  String get gymUser => 'Usuário';

  @override
  String get editDisplayName => 'Editar Nome';

  @override
  String get enterYourName => 'Digite seu nome';

  @override
  String get workouts => 'Treinos';

  @override
  String get memberSince => 'Membro desde';

  @override
  String get weightUnit => 'Unidade de Peso';

  @override
  String get weeklyGoal => 'Meta Semanal';

  @override
  String get dataManagement => 'GERENCIAMENTO DE DADOS';

  @override
  String get manageData => 'Gerenciar Dados';

  @override
  String get legal => 'JURÍDICO';

  @override
  String get sendCrashReports => 'Enviar relatórios de erro';

  @override
  String get crashReportsSubtitle =>
      'Ajude a melhorar o RepSaga enviando dados anônimos de falhas.';

  @override
  String get logOutConfirm => 'Tem certeza que deseja sair?';

  @override
  String get manageDataTitle => 'Gerenciar Dados';

  @override
  String get deleteWorkoutHistory => 'Excluir Histórico de Treinos';

  @override
  String workoutsWillBeRemoved(String count) {
    return '$count treinos serão removidos';
  }

  @override
  String get resetAllAccountData => 'Redefinir Todos os Dados';

  @override
  String get resetAllSubtitle => 'Remove tudo. Permanente.';

  @override
  String get deleteAccount => 'Excluir Conta';

  @override
  String get deleteAccountSubtitle =>
      'Excluir permanentemente sua conta e todos os dados';

  @override
  String get deleteAllHistoryTitle => 'Excluir todo o histórico de treinos?';

  @override
  String deleteAllHistoryContent(int count) {
    return 'Isso excluirá permanentemente todos os $count treinos e não pode ser desfeito.';
  }

  @override
  String get deleteHistoryButton => 'Excluir Histórico';

  @override
  String get areYouSure => 'Tem certeza?';

  @override
  String get yesDelete => 'Sim, Excluir';

  @override
  String get historyCleared => 'Histórico de treinos limpo';

  @override
  String failedToClearHistory(String message) {
    return 'Falha ao limpar histórico: $message';
  }

  @override
  String get resetAccountData => 'Redefinir Dados da Conta';

  @override
  String get resetAccountWarning =>
      'Isso excluirá permanentemente todos os treinos e recordes pessoais. Suas rotinas e exercícios personalizados serão mantidos. Não há como desfazer.';

  @override
  String get typeResetToConfirm => 'Digite RESET para confirmar';

  @override
  String get resetAccountButton => 'Redefinir Conta';

  @override
  String get accountDataReset => 'Dados da conta redefinidos';

  @override
  String failedToResetData(String message) {
    return 'Falha ao redefinir dados: $message';
  }

  @override
  String get deleteAccountWarning =>
      'Isso excluirá permanentemente sua conta, todos os seus treinos, recordes pessoais, rotinas e exercícios personalizados. Esta ação não pode ser desfeita.';

  @override
  String get typeDeleteToConfirm => 'Digite DELETE para confirmar';

  @override
  String get deleteAccountButton => 'Excluir Conta';

  @override
  String failedToDeleteAccount(String message) {
    return 'Falha ao excluir conta: $message';
  }

  @override
  String get prsRoutinesKept =>
      'Seus recordes pessoais e rotinas serão mantidos.';

  @override
  String get workoutHistorySection => 'HISTÓRICO DE TREINOS';

  @override
  String get dangerSection => 'PERIGO';

  @override
  String get privacySection => 'PRIVACIDADE';

  @override
  String get prsLabel => 'PRs';

  @override
  String perWeekLabel(int count) {
    return '${count}x por semana';
  }

  @override
  String get frequencyQuestion => 'Quantas vezes por semana você quer treinar?';

  @override
  String get pleaseTryAgain => 'Tente novamente.';

  @override
  String get personalRecordsTitle => 'Recordes Pessoais';

  @override
  String get failedToLoadRecords => 'Falha ao carregar recordes';

  @override
  String get noRecordsYetTitle => 'Nenhum Recorde Ainda';

  @override
  String get completeWorkoutToTrack =>
      'Complete um treino para começar a registrar recordes';

  @override
  String get startWorkout => 'Iniciar Treino';

  @override
  String get newPrHeading => 'NOVO PR';

  @override
  String get firstWorkoutComplete => 'Primeiro Treino Concluído!';

  @override
  String get startingBenchmarks => 'Estes são seus primeiros registros';

  @override
  String get unknownExercise => 'Exercício Desconhecido';

  @override
  String get thisWeeksPlan => 'Plano da Semana';

  @override
  String get moreOptions => 'Mais opções';

  @override
  String get autoFill => 'Preencher automático';

  @override
  String get clearWeek => 'Limpar Semana';

  @override
  String get addRoutine => 'Adicionar Rotina';

  @override
  String plannedReadyToGo(int count, int total) {
    return '$count/$total planejados — pronto para treinar';
  }

  @override
  String plannedThisWeek(int count, int total) {
    return '$count/$total planejados esta semana';
  }

  @override
  String get noRoutinesPlanned => 'Nenhuma rotina planejada esta semana';

  @override
  String get addRoutines => 'Adicionar Rotinas';

  @override
  String get replacePlanTitle => 'Substituir plano atual?';

  @override
  String get replacePlanContent =>
      'O preenchimento automático substituirá seu plano atual pelas rotinas mais usadas.';

  @override
  String get clearWeekTitle => 'Limpar Semana';

  @override
  String get clearWeekContent => 'Começar do zero esta semana?';

  @override
  String get routineRemoved => 'Rotina removida';

  @override
  String get unknownRoutine => 'Rotina Desconhecida';

  @override
  String get addRoutinesSheet => 'Adicionar Rotinas';

  @override
  String get allRoutinesInPlan => 'Todas as rotinas estão no plano';

  @override
  String get createMoreRoutines => 'Crie mais rotinas para adicioná-las aqui.';

  @override
  String addCountRoutines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ADICIONAR $count ROTINAS',
      one: 'ADICIONAR 1 ROTINA',
    );
    return '$_temp0';
  }

  @override
  String get weekComplete => 'SEMANA COMPLETA';

  @override
  String get thisWeek => 'ESTA SEMANA';

  @override
  String get newWeekLink => 'NOVA SEMANA';

  @override
  String sessionsCount(int count) {
    return '$count sessões';
  }

  @override
  String prsCount(int count) {
    return '$count PRs';
  }

  @override
  String addToPlanPrompt(String name) {
    return '$name não está no seu plano ainda. Adicionar?';
  }

  @override
  String get syncFailureSingular => 'O treino não sincronizou';

  @override
  String syncFailurePlural(int count) {
    return '$count treinos não sincronizaram';
  }

  @override
  String get savedLocallyRetry =>
      'Salvo localmente. Tente novamente ou dispense.';

  @override
  String get offlineRetryHint =>
      'Você está offline — tente novamente quando voltar a ficar online';

  @override
  String get pendingSyncTitle => 'Sincronização Pendente';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get allSynced => 'Tudo sincronizado!';

  @override
  String get syncedSuccessfully => 'Sincronizado com sucesso.';

  @override
  String get pendingActionSaveWorkout => 'Salvar treino';

  @override
  String get pendingActionUpdateRecords => 'Atualizar recordes';

  @override
  String get pendingActionMarkComplete => 'Marcar rotina como concluída';

  @override
  String queuedAt(String time) {
    return 'Na fila às $time';
  }

  @override
  String retryCount(int count) {
    return '$count tentativas';
  }

  @override
  String get pendingSyncBadgeSingular => '1 treino pendente de sincronização';

  @override
  String pendingSyncBadgePlural(int count) {
    return '$count treinos pendentes de sincronização';
  }

  @override
  String get noExercisesFound => 'Nenhum exercício encontrado';

  @override
  String get failedToLoadExercises => 'Falha ao carregar exercícios';

  @override
  String createWithName(String name) {
    return 'Criar \"$name\"';
  }

  @override
  String get durationLessThanOneMin => '< 1m';

  @override
  String get enterWeight => 'Insira o peso';

  @override
  String get ok => 'OK';

  @override
  String get enterReps => 'Insira as reps';

  @override
  String get failedToLoadDocument => 'Falha ao carregar documento';

  @override
  String get discardWorkout => 'Descartar treino';

  @override
  String get moveUp => 'Mover para cima';

  @override
  String get moveDown => 'Mover para baixo';

  @override
  String get swapExercise => 'Trocar exercício';

  @override
  String get removeExercise => 'Remover exercício';

  @override
  String get rpeTooltip => 'Percepção subjetiva de esforço';

  @override
  String get last30Days => '30d';

  @override
  String get last90Days => '90d';

  @override
  String get allTime => 'Tudo';

  @override
  String switchMetricTo(String metric) {
    return 'Mudar métrica para $metric';
  }

  @override
  String get couldNotLoadProgress => 'Não foi possível carregar progresso';

  @override
  String get logFirstSetToTrack =>
      'Registre sua primeira série para começar a acompanhar';

  @override
  String get chartMetricE1rm => 'e1RM';

  @override
  String get chartMetricWeight => 'Peso';

  @override
  String get chartWindowDays30 => '30 dias';

  @override
  String get chartWindowDays90 => '90 dias';

  @override
  String get chartWindowAllTime => 'todo o período';

  @override
  String workoutsLoggedKeepGoing(int count) {
    return '$count treinos registrados — continue assim';
  }

  @override
  String get oneWorkoutLoggedKeepGoing =>
      '1 treino registrado — continue assim';

  @override
  String holdingSteadyAt(String weight, String unit) {
    return 'Estável em $weight $unit';
  }

  @override
  String trendUp(String weight, String unit, String window) {
    return 'Subiu $weight $unit em $window';
  }

  @override
  String trendDown(String weight, String unit, String window) {
    return 'Desceu $weight $unit em $window';
  }

  @override
  String prMarkerAt(String weight, String unit) {
    return 'Marcador de PR em $weight $unit';
  }

  @override
  String setNumberSemantics(int number, String type) {
    return 'Série $number. Toque e segure para mudar o tipo: $type';
  }

  @override
  String setNumberCopySemantics(int number, String type) {
    return 'Série $number. Toque para copiar série anterior. Toque e segure para mudar o tipo: $type';
  }

  @override
  String get tooltipCopyLastSetAndChangeType =>
      'Toque: copiar última série\nSegure: mudar tipo';

  @override
  String get tooltipChangeType => 'Segure: mudar tipo';

  @override
  String get setCompleted => 'Série concluída';

  @override
  String get markSetAsDone => 'Marcar série como concluída';

  @override
  String rpeValue(int value) {
    return 'RPE $value. Toque para alterar.';
  }

  @override
  String get setRpe => 'Definir RPE';

  @override
  String get rpeLabel => 'RPE';

  @override
  String rpeMenuItem(int value) {
    return 'RPE $value';
  }

  @override
  String get reorderExercisesTooltip => 'Reordenar exercícios';

  @override
  String get exitReorderModeTooltip => 'Sair do modo de reordenação';

  @override
  String exerciseSemanticsLabel(String name) {
    return 'Exercício: $name. Toque para detalhes. Toque e segure para trocar.';
  }

  @override
  String get fillRemainingSetsSemantics =>
      'Preencher séries restantes com os últimos valores';

  @override
  String get addExerciseToWorkoutSemantics => 'Adicionar exercício ao treino';

  @override
  String get searchExercisesToAddSemantics =>
      'Buscar exercícios para adicionar';

  @override
  String addExerciseSemantics(String name) {
    return 'Adicionar $name';
  }

  @override
  String get setTypeAbbrWorking => 'N';

  @override
  String get setTypeAbbrWarmup => 'AQ';

  @override
  String get setTypeAbbrDropset => 'D';

  @override
  String get setTypeAbbrFailure => 'F';

  @override
  String get setTypeAbbrWarmupShort => 'Aq';

  @override
  String lastSessionSemantics(String name, String date) {
    return 'Última sessão: $name, $date';
  }

  @override
  String get searchExercisesSemantics => 'Buscar exercícios';

  @override
  String exerciseItemSemantics(String name) {
    return 'Exercício: $name';
  }

  @override
  String get createNewExerciseSemantics => 'Criar novo exercício';

  @override
  String get muscleGroupSemanticsPrefix => 'Grupo muscular';

  @override
  String get equipmentTypeSemanticsPrefix => 'Tipo de equipamento';

  @override
  String get deleteExerciseSemantics => 'Excluir exercício';

  @override
  String get exerciseNameDuplicate => 'Um exercício com este nome já existe';

  @override
  String daysAgoShort(int count) {
    return '${count}d atrás';
  }

  @override
  String weeksAgoShort(int count) {
    return '${count}sem atrás';
  }

  @override
  String monthsAgoShort(int count) {
    return '${count}m atrás';
  }

  @override
  String get routineNamePushDay => 'Dia de Empurrar';

  @override
  String get routineNamePullDay => 'Dia de Puxar';

  @override
  String get routineNameLegDay => 'Dia de Pernas';

  @override
  String get routineNameFullBody => 'Corpo Inteiro';

  @override
  String get routineNameUpperLowerUpper => 'Superior/Inferior — Superior';

  @override
  String get routineNameUpperLowerLower => 'Superior/Inferior — Inferior';

  @override
  String get routineNameFiveByFiveStrength => '5x5 Força';

  @override
  String get routineNameFullBodyBeginner => 'Corpo Inteiro Iniciante';

  @override
  String get routineNameArmsAndAbs => 'Braços e Abdômen';

  @override
  String get preferences => 'PREFERÊNCIAS';

  @override
  String get language => 'Idioma';

  @override
  String get sagaIntroStep1Title => 'SEU TREINO É SEU PERSONAGEM';

  @override
  String get sagaIntroStep1Body =>
      'Cada série concluída define quem você se torna. Treine, registre, evolua.';

  @override
  String get sagaIntroStep2Title => 'XP DE CADA SÉRIE, PR E MISSÃO';

  @override
  String get sagaIntroStep2Body =>
      'Volume, intensidade, recordes pessoais e missões semanais geram XP.';

  @override
  String sagaIntroStep3Title(int level, String rank) {
    return 'NÍVEL $level — $rank';
  }

  @override
  String get sagaIntroStep3Body =>
      'Sua jornada começa aqui. Continue treinando para subir de rank.';

  @override
  String get sagaIntroNext => 'PRÓXIMO';

  @override
  String get sagaIntroBegin => 'COMEÇAR';

  @override
  String get sagaRankRookie => 'NOVATO';

  @override
  String get sagaRankIron => 'FERRO';

  @override
  String get sagaRankCopper => 'BRONZE';

  @override
  String get sagaRankSilver => 'PRATA';

  @override
  String get sagaRankGold => 'OURO';

  @override
  String get sagaRankPlatinum => 'PLATINA';

  @override
  String get sagaRankDiamond => 'DIAMANTE';
}
