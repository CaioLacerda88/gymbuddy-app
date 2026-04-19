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
  String get offlineBanner => 'Você está offline';

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
}
