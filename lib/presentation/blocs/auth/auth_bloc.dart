import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/user_repository.dart';

// Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class SignInRequested extends AuthEvent {
  final String email;
  final String password;
  const SignInRequested(this.email, this.password);
  @override
  List<Object?> get props => [email, password];
}

class SignUpRequested extends AuthEvent {
  final String email;
  final String password;
  const SignUpRequested(this.email, this.password);
  @override
  List<Object?> get props => [email, password];
}

class SignOutRequested extends AuthEvent {}

class AuthStateChanged extends AuthEvent {
  final String? userId;
  const AuthStateChanged(this.userId);
  @override
  List<Object?> get props => [userId];
}

// States
abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class Authenticated extends AuthState {
  final String userId;
  const Authenticated(this.userId);
  @override
  List<Object?> get props => [userId];
}
class Unauthenticated extends AuthState {}
class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final UserRepository userRepository;

  AuthBloc({required this.userRepository}) : super(AuthInitial()) {
    on<SignInRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await userRepository.signIn(event.email, event.password);
      } catch (e) {
        String errorMsg = e.toString();
        if (errorMsg.contains('AuthException')) {
          try {
            errorMsg = errorMsg.split('message: ')[1].split(',')[0];
          } catch (_) {}
        }
        emit(AuthError(errorMsg));
      }
    });

    on<SignUpRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await userRepository.signUp(event.email, event.password);
        // If the user is not automatically logged in, it means email confirmation is required.
        if (userRepository.currentUserEmail == null) {
          emit(AuthError('Account created! Please check your email to verify.'));
        }
      } catch (e) {
        // Supabase throws AuthException, e.toString() contains the message
        String errorMsg = e.toString();
        if (errorMsg.contains('AuthException')) {
          errorMsg = errorMsg.split('message: ')[1].split(',')[0];
        }
        emit(AuthError(errorMsg));
      }
    });

    on<SignOutRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await userRepository.signOut();
      } catch (e) {
        emit(AuthError(e.toString()));
      }
    });

    on<AuthStateChanged>((event, emit) {
      if (event.userId != null) {
        emit(Authenticated(event.userId!));
      } else {
        emit(Unauthenticated());
      }
    });

    userRepository.authStateChanges.listen((userId) {
      add(AuthStateChanged(userId));
    });
  }
}
