{{/*
_helpers.tpl - named templates shared by every file in templates/.
Files whose names start with "_" never produce Kubernetes objects.
*/}}

{{/* visitapp.name: the chart name, or nameOverride when set. */}}
{{- define "visitapp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
visitapp.fullname: base name of every object.
If the release name already contains the chart name it is used alone,
so release "visitapp-dev" gives "visitapp-dev", not "visitapp-dev-visitapp".
*/}}
{{- define "visitapp.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
visitapp.componentName: name of one tier's objects, e.g. "visitapp-dev-backend".
Called with a dict:  include "visitapp.componentName" (dict "ctx" . "component" "backend")
Truncated to 52 characters so that StatefulSet Pod names and PVC names,
which add suffixes, stay within Kubernetes limits.
*/}}
{{- define "visitapp.componentName" -}}
{{- printf "%s-%s" (include "visitapp.fullname" .ctx | trunc 40 | trimSuffix "-") .component | trunc 52 | trimSuffix "-" }}
{{- end }}

{{/* visitapp.chart: "<name>-<version>" for the helm.sh/chart label. */}}
{{- define "visitapp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
visitapp.environment: the environment name. Rendering stops with a clear
message if it was not set, so no object can exist without an environment.
*/}}
{{- define "visitapp.environment" -}}
{{- required "global.environment must be set (dev, staging or prod). Pass -f environments/<env>.yaml" .Values.global.environment }}
{{- end }}

{{/*
visitapp.selectorLabels: the small, stable label set used by selectors.
NEVER add a label that changes between versions here: Deployment and
StatefulSet selectors are immutable after the first install.
Called with a dict: (dict "ctx" . "component" "backend")
*/}}
{{- define "visitapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "visitapp.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
visitapp.labels: the full recommended label set for every object.
Called with a dict: (dict "ctx" . "component" "backend")
*/}}
{{- define "visitapp.labels" -}}
helm.sh/chart: {{ include "visitapp.chart" .ctx }}
{{ include "visitapp.selectorLabels" . }}
app.kubernetes.io/part-of: {{ include "visitapp.name" .ctx }}
app.kubernetes.io/version: {{ .ctx.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .ctx.Release.Service }}
dso202/environment: {{ include "visitapp.environment" .ctx | quote }}
{{- end }}

{{/* visitapp.redisSecretName: the Secret that holds the Redis password. */}}
{{- define "visitapp.redisSecretName" -}}
{{- include "visitapp.componentName" (dict "ctx" . "component" "redis") }}
{{- end }}

{{/*
visitapp.redisPassword: the Redis password, in this order of preference:
  1. redis.auth.password from values, if set;
  2. the password already stored in the cluster (lookup), so upgrades keep it;
  3. a new random 24-character password (first install only).
lookup returns nothing under "helm template", so a template render shows a
new random value each time; a real install or upgrade does not.
*/}}
{{- define "visitapp.redisPassword" -}}
{{- if .Values.redis.auth.password }}
{{- .Values.redis.auth.password }}
{{- else }}
{{- $existing := lookup "v1" "Secret" .Release.Namespace (include "visitapp.redisSecretName" .) }}
{{- if and $existing $existing.data (hasKey $existing.data "redis-password") }}
{{- index $existing.data "redis-password" | b64dec }}
{{- else }}
{{- randAlphaNum 24 }}
{{- end }}
{{- end }}
{{- end }}
