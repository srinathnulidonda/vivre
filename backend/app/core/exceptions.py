# app/core/exceptions.py


class AppError(Exception):
    def __init__(self, message: str, code: str, status_code: int) -> None:
        self.message = message
        self.code = code
        self.status_code = status_code
        super().__init__(message)


class NotFoundError(AppError):
    def __init__(self, message: str = "Resource not found") -> None:
        super().__init__(message=message, code="not_found", status_code=404)


class PermissionDeniedError(AppError):
    def __init__(self, message: str = "Permission denied") -> None:
        super().__init__(message=message, code="permission_denied", status_code=403)


class ConflictError(AppError):
    def __init__(self, message: str = "Conflict") -> None:
        super().__init__(message=message, code="conflict", status_code=409)


class ValidationError(AppError):
    def __init__(self, message: str = "Validation failed") -> None:
        super().__init__(message=message, code="validation_error", status_code=422)


class PayloadTooLargeError(AppError):
    code = "payload_too_large"
    status_code = 413

    def __init__(self, message: str = "Request payload too large") -> None:
        super().__init__(message=message, code=self.code, status_code=self.status_code)