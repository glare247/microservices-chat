# coding=utf-8
from __future__ import unicode_literals, print_function, absolute_import, division
from flask import Blueprint

messages_bp = Blueprint('messages', __name__)

from project.views import views  # noqa: E402, F401
