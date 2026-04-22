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
  String get muscleGroupCore => 'Núcleo';

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
  String get equipmentBands => 'Faixas Elásticas';

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
  String get exerciseName_barbell_bench_press => 'Supino Reto com Barra';

  @override
  String get exerciseName_incline_barbell_bench_press =>
      'Supino Inclinado com Barra';

  @override
  String get exerciseName_decline_barbell_bench_press =>
      'Supino Declinado com Barra';

  @override
  String get exerciseName_dumbbell_bench_press => 'Supino Reto com Halteres';

  @override
  String get exerciseName_incline_dumbbell_press =>
      'Supino Inclinado com Halteres';

  @override
  String get exerciseName_dumbbell_fly => 'Crucifixo com Halteres';

  @override
  String get exerciseName_cable_crossover => 'Crossover no Cabo';

  @override
  String get exerciseName_machine_chest_press => 'Supino na Máquina';

  @override
  String get exerciseName_push_up => 'Flexão de Braços';

  @override
  String get exerciseName_barbell_bent_over_row => 'Remada Curvada com Barra';

  @override
  String get exerciseName_deadlift => 'Levantamento Terra';

  @override
  String get exerciseName_t_bar_row => 'Remada Cavalinho';

  @override
  String get exerciseName_dumbbell_row => 'Remada Unilateral com Halter';

  @override
  String get exerciseName_dumbbell_pullover => 'Pullover com Halter';

  @override
  String get exerciseName_cable_row => 'Remada no Cabo';

  @override
  String get exerciseName_lat_pulldown => 'Puxada na Polia Alta';

  @override
  String get exerciseName_pull_up => 'Barra Fixa';

  @override
  String get exerciseName_chin_up => 'Barra Fixa Supinada';

  @override
  String get exerciseName_machine_row => 'Remada na Máquina';

  @override
  String get exerciseName_barbell_squat => 'Agachamento com Barra';

  @override
  String get exerciseName_front_squat => 'Agachamento Frontal';

  @override
  String get exerciseName_romanian_deadlift => 'Levantamento Terra Romeno';

  @override
  String get exerciseName_hip_thrust => 'Elevação de Quadril com Barra';

  @override
  String get exerciseName_dumbbell_lunges => 'Afundo com Halteres';

  @override
  String get exerciseName_bulgarian_split_squat => 'Agachamento Búlgaro';

  @override
  String get exerciseName_goblet_squat => 'Agachamento Goblet';

  @override
  String get exerciseName_leg_press => 'Leg Press';

  @override
  String get exerciseName_leg_extension => 'Cadeira Extensora';

  @override
  String get exerciseName_leg_curl => 'Mesa Flexora';

  @override
  String get exerciseName_calf_raise => 'Elevação de Panturrilha';

  @override
  String get exerciseName_overhead_press => 'Desenvolvimento com Barra';

  @override
  String get exerciseName_push_press => 'Push Press';

  @override
  String get exerciseName_dumbbell_shoulder_press =>
      'Desenvolvimento com Halteres';

  @override
  String get exerciseName_arnold_press => 'Arnold Press';

  @override
  String get exerciseName_lateral_raise => 'Elevação Lateral';

  @override
  String get exerciseName_front_raise => 'Elevação Frontal';

  @override
  String get exerciseName_rear_delt_fly => 'Crucifixo Invertido';

  @override
  String get exerciseName_cable_face_pull => 'Face Pull no Cabo';

  @override
  String get exerciseName_barbell_curl => 'Rosca Direta com Barra';

  @override
  String get exerciseName_ez_bar_curl => 'Rosca com Barra W';

  @override
  String get exerciseName_skull_crusher => 'Tríceps Testa';

  @override
  String get exerciseName_dumbbell_curl => 'Rosca com Halteres';

  @override
  String get exerciseName_hammer_curl => 'Rosca Martelo';

  @override
  String get exerciseName_concentration_curl => 'Rosca Concentrada';

  @override
  String get exerciseName_dumbbell_tricep_extension =>
      'Extensão de Tríceps com Halter';

  @override
  String get exerciseName_tricep_pushdown => 'Tríceps na Polia';

  @override
  String get exerciseName_cable_curl => 'Rosca no Cabo';

  @override
  String get exerciseName_dips => 'Paralelas';

  @override
  String get exerciseName_plank => 'Prancha';

  @override
  String get exerciseName_hanging_leg_raise => 'Elevação de Pernas Suspenso';

  @override
  String get exerciseName_crunches => 'Abdominal';

  @override
  String get exerciseName_ab_rollout => 'Roda Abdominal';

  @override
  String get exerciseName_russian_twist => 'Giro Russo';

  @override
  String get exerciseName_dead_bug => 'Dead Bug';

  @override
  String get exerciseName_cable_woodchop => 'Woodchop no Cabo';

  @override
  String get exerciseName_band_pull_apart => 'Band Pull-Apart';

  @override
  String get exerciseName_band_face_pull => 'Face Pull com Faixa';

  @override
  String get exerciseName_band_squat => 'Agachamento com Faixa';

  @override
  String get exerciseName_kettlebell_swing => 'Kettlebell Swing';

  @override
  String get exerciseName_kettlebell_goblet_squat =>
      'Agachamento Goblet com Kettlebell';

  @override
  String get exerciseName_kettlebell_turkish_get_up =>
      'Levantamento Turco com Kettlebell';

  @override
  String get exerciseName_pec_deck => 'Pec Deck';

  @override
  String get exerciseName_cable_chest_press => 'Supino no Cabo';

  @override
  String get exerciseName_wide_push_up => 'Flexão Aberta';

  @override
  String get exerciseName_face_pull => 'Face Pull';

  @override
  String get exerciseName_rack_pull => 'Rack Pull';

  @override
  String get exerciseName_good_morning => 'Good Morning';

  @override
  String get exerciseName_pendlay_row => 'Remada Pendlay';

  @override
  String get exerciseName_hack_squat => 'Hack Squat';

  @override
  String get exerciseName_sumo_deadlift => 'Levantamento Terra Sumo';

  @override
  String get exerciseName_walking_lunges => 'Afundo Caminhando';

  @override
  String get exerciseName_step_up => 'Step-Up';

  @override
  String get exerciseName_seated_calf_raise => 'Panturrilha Sentado';

  @override
  String get exerciseName_leg_abductor => 'Abdutora';

  @override
  String get exerciseName_leg_adductor => 'Adutora';

  @override
  String get exerciseName_upright_row => 'Remada Alta';

  @override
  String get exerciseName_machine_shoulder_press =>
      'Desenvolvimento na Máquina';

  @override
  String get exerciseName_cable_lateral_raise => 'Elevação Lateral no Cabo';

  @override
  String get exerciseName_preacher_curl => 'Rosca Scott';

  @override
  String get exerciseName_incline_dumbbell_curl =>
      'Rosca Inclinada com Halteres';

  @override
  String get exerciseName_close_grip_bench_press => 'Supino Pegada Fechada';

  @override
  String get exerciseName_overhead_tricep_extension =>
      'Extensão de Tríceps Overhead no Cabo';

  @override
  String get exerciseName_rope_pushdown => 'Tríceps na Corda';

  @override
  String get exerciseName_bicycle_crunch => 'Abdominal Bicicleta';

  @override
  String get exerciseName_cable_crunch => 'Abdominal no Cabo';

  @override
  String get exerciseName_pallof_press => 'Pallof Press';

  @override
  String get exerciseName_side_plank => 'Prancha Lateral';

  @override
  String get exerciseName_treadmill => 'Esteira';

  @override
  String get exerciseName_rowing_machine => 'Remo Ergométrico';

  @override
  String get exerciseName_stationary_bike => 'Bicicleta Ergométrica';

  @override
  String get exerciseName_jump_rope => 'Pular Corda';

  @override
  String get exerciseName_elliptical => 'Elíptico';

  @override
  String get exerciseName_incline_dumbbell_fly =>
      'Crucifixo Inclinado com Halteres';

  @override
  String get exerciseName_decline_dumbbell_press =>
      'Supino Declinado com Halteres';

  @override
  String get exerciseName_landmine_press => 'Landmine Press';

  @override
  String get exerciseName_diamond_push_up => 'Flexão Diamante';

  @override
  String get exerciseName_incline_push_up => 'Flexão Inclinada';

  @override
  String get exerciseName_decline_push_up => 'Flexão Declinada';

  @override
  String get exerciseName_hyperextension => 'Hiperextensão';

  @override
  String get exerciseName_back_extension => 'Extensão de Costas';

  @override
  String get exerciseName_inverted_row => 'Remada Invertida';

  @override
  String get exerciseName_chest_supported_row => 'Remada com Apoio no Peito';

  @override
  String get exerciseName_seal_row => 'Seal Row';

  @override
  String get exerciseName_straight_arm_pulldown =>
      'Puxada com Braços Estendidos';

  @override
  String get exerciseName_close_grip_lat_pulldown => 'Puxada Pegada Fechada';

  @override
  String get exerciseName_wide_grip_pull_up => 'Barra Fixa Pegada Aberta';

  @override
  String get exerciseName_kettlebell_row => 'Remada com Kettlebell';

  @override
  String get exerciseName_glute_bridge => 'Elevação de Quadril';

  @override
  String get exerciseName_single_leg_glute_bridge =>
      'Elevação de Quadril Unilateral';

  @override
  String get exerciseName_box_jump => 'Salto na Caixa';

  @override
  String get exerciseName_nordic_curl => 'Nordic Curl';

  @override
  String get exerciseName_wall_sit => 'Agachamento na Parede';

  @override
  String get exerciseName_donkey_kick => 'Coice de Burro';

  @override
  String get exerciseName_bodyweight_squat => 'Agachamento Livre';

  @override
  String get exerciseName_reverse_lunges => 'Afundo Reverso';

  @override
  String get exerciseName_dumbbell_calf_raise => 'Panturrilha com Halteres';

  @override
  String get exerciseName_single_leg_leg_press => 'Leg Press Unilateral';

  @override
  String get exerciseName_reverse_hyperextension => 'Hiperextensão Reversa';

  @override
  String get exerciseName_cable_glute_kickback => 'Glúteo no Cabo';

  @override
  String get exerciseName_cable_pull_through => 'Pull-Through no Cabo';

  @override
  String get exerciseName_kettlebell_deadlift =>
      'Levantamento Terra com Kettlebell';

  @override
  String get exerciseName_barbell_shrug => 'Encolhimento com Barra';

  @override
  String get exerciseName_dumbbell_shrug => 'Encolhimento com Halteres';

  @override
  String get exerciseName_cable_rear_delt_fly => 'Crucifixo Invertido no Cabo';

  @override
  String get exerciseName_cable_front_raise => 'Elevação Frontal no Cabo';

  @override
  String get exerciseName_reverse_pec_deck => 'Pec Deck Invertido';

  @override
  String get exerciseName_landmine_shoulder_press => 'Desenvolvimento Landmine';

  @override
  String get exerciseName_kettlebell_press => 'Desenvolvimento com Kettlebell';

  @override
  String get exerciseName_spider_curl => 'Rosca Aranha';

  @override
  String get exerciseName_zottman_curl => 'Rosca Zottman';

  @override
  String get exerciseName_reverse_curl => 'Rosca Inversa';

  @override
  String get exerciseName_wrist_curl => 'Rosca de Punho';

  @override
  String get exerciseName_reverse_wrist_curl => 'Rosca de Punho Inversa';

  @override
  String get exerciseName_farmer_s_walk => 'Caminhada do Fazendeiro';

  @override
  String get exerciseName_cable_hammer_curl => 'Rosca Martelo no Cabo';

  @override
  String get exerciseName_bench_dip => 'Mergulho no Banco';

  @override
  String get exerciseName_close_grip_push_up => 'Flexão Pegada Fechada';

  @override
  String get exerciseName_jm_press => 'JM Press';

  @override
  String get exerciseName_sit_up => 'Abdominal Completo';

  @override
  String get exerciseName_mountain_climber => 'Escalador';

  @override
  String get exerciseName_toe_touch => 'Toque nos Pés';

  @override
  String get exerciseName_hollow_body_hold => 'Hollow Body Hold';

  @override
  String get exerciseName_v_up => 'V-Up';

  @override
  String get exerciseName_flutter_kick => 'Flutter Kick';

  @override
  String get exerciseName_reverse_crunch => 'Abdominal Reverso';

  @override
  String get exerciseName_leg_raise => 'Elevação de Pernas';

  @override
  String get exerciseName_windshield_wiper => 'Limpador de Para-brisa';

  @override
  String get exerciseName_plank_up_down => 'Prancha Sobe e Desce';

  @override
  String get exerciseName_heel_touch => 'Toque no Calcanhar';

  @override
  String get exerciseName_kettlebell_windmill => 'Moinho com Kettlebell';

  @override
  String get preferences => 'PREFERÊNCIAS';

  @override
  String get language => 'Idioma';
}
