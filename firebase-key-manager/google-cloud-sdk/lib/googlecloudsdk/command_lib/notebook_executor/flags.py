# -*- coding: utf-8 -*- #
# Copyright 2024 Google LLC. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Utilities for flags for `gcloud notebook-executor` commands."""

from googlecloudsdk.api_lib.notebook_executor import executions as executions_util
from googlecloudsdk.calliope import arg_parsers
from googlecloudsdk.calliope import base
from googlecloudsdk.calliope.concepts import concepts
from googlecloudsdk.command_lib.util.concepts import concept_parsers
from googlecloudsdk.command_lib.util.concepts import presentation_specs


def GetRegionAttributeConfig():
  return concepts.ResourceParameterAttributeConfig(
      name='region',
      help_text='Cloud region for the {resource}.',
  )


def AddExecutionResourceArg(parser, verb):
  """Add a resource argument for an execution to the parser.

  Args:
    parser: argparse parser for the command.
    verb: str, the verb to describe the resource, such as 'to update'.
  """

  def GetExecutionResourceSpec(resource_name='notebook execution job'):
    return concepts.ResourceSpec(
        'aiplatform.projects.locations.notebookExecutionJobs',
        resource_name=resource_name,
        projectsId=concepts.DEFAULT_PROJECT_ATTRIBUTE_CONFIG,
        locationsId=GetRegionAttributeConfig(),
    )

  concept_parsers.ConceptParser.ForResource(
      'execution',
      GetExecutionResourceSpec(),
      'Unique name of the execution {}. This was optionally provided by setting'
      ' --execution-job-id in the create execution command or was'
      ' system-generated if unspecified.'.format(verb),
      required=True,
  ).AddToParser(parser)


def AddDataformRepositoryResourceArg(parser):
  """Add a resource argument for a Dataform repository to the parser.

  Args:
    parser: argparse parser for the command.

  """
  def GetDataformRepositoryResourceSpec(resource_name='dataform repository'):
    return concepts.ResourceSpec(
        'dataform.projects.locations.repositories',
        resource_name=resource_name,
        projectsId=concepts.DEFAULT_PROJECT_ATTRIBUTE_CONFIG,
        locationsId=GetRegionAttributeConfig(),
    )

  dataform_repository_resource = presentation_specs.ResourcePresentationSpec(
      '--dataform-repository-name',
      GetDataformRepositoryResourceSpec(),
      'Unique name of the Dataform repository to source input notebook from.',
      required=True,
      # This hides the region flag for the dataform repository, but as a GCP
      # resource the dataform flag will still accept a fully qualified name
      # ('projects/*/locations/*/repositories/*') or just the repository ID.
      flag_name_overrides={'region': ''},
  )
  concept_parsers.ConceptParser(
      [dataform_repository_resource],
      # By default the region flag will be the execution region.
      command_level_fallthroughs={
          '--dataform-repository-name.region': ['--region']
      },
  ).AddToParser(parser)


def AddRegionResourceArg(parser, verb):
  """Add a resource argument for a Vertex AI region to the parser.

  Args:
    parser: argparse parser for the command.
    verb: str, the verb to describe the resource, such as 'to update'.

  """
  region_resource_spec = concepts.ResourceSpec(
      'aiplatform.projects.locations',
      resource_name='region',
      locationsId=GetRegionAttributeConfig(),
      projectsId=concepts.DEFAULT_PROJECT_ATTRIBUTE_CONFIG,
  )

  concept_parsers.ConceptParser.ForResource(
      '--region',
      region_resource_spec,
      'Cloud region {}.'.format(verb),
      required=True,
  ).AddToParser(parser)


def AddRuntimeTemplateResourceArg(parser):
  """Add a resource argument for a runtime template to the parser.

  Args:
    parser: argparse parser for the command.
  """

  def GetRuntimeTemplateResourceSpec(resource_name='notebook runtime template'):
    return concepts.ResourceSpec(
        'aiplatform.projects.locations.notebookRuntimeTemplates',
        resource_name=resource_name,
        projectsId=concepts.DEFAULT_PROJECT_ATTRIBUTE_CONFIG,
        locationsId=GetRegionAttributeConfig(),
    )

  runtime_template_resource = presentation_specs.ResourcePresentationSpec(
      '--notebook-runtime-template',
      GetRuntimeTemplateResourceSpec(),
      'The runtime template specifying the compute configuration for the'
      ' notebook execution. The runtime template should be in the same region'
      ' as the execution.',
      required=True,
      # This hides the region flag for the runtime template, but as a GCP
      # resource the flag will still accept a fully qualified name
      # ('projects/*/locations/*/notebookRuntimeTemplates/*') or just the ID.
      flag_name_overrides={'region': ''},
  )
  concept_parsers.ConceptParser(
      [runtime_template_resource],
      # By default the region flag will be the execution region.
      command_level_fallthroughs={
          '--notebook-runtime-template.region': ['--region']
      },
  ).AddToParser(parser)


def AddCreateExecutionFlags(parser):
  """Adds flags for creating an execution to the parser."""
  AddRegionResourceArg(parser, 'to create')
  execution_group = parser.add_group(
      help='Configuration of the execution job.',
      required=True,
  )
  execution_group.add_argument(
      '--display-name',
      help='The display name of the execution.',
      required=True,
  )
  notebook_source_group = execution_group.add_group(
      help='Source of the notebook to execute.',
      required=True,
      mutex=True,
  )
  dataform_source_group = notebook_source_group.add_group(
      help=(
          'The Dataform repository containing the notebook. Any notebook'
          ' created from the Colab UI is automatically stored in a Dataform'
          ' repository. The repository name can be found via the Dataform'
          ' API by listing repositories in the same project and region as the'
          ' notebook.'
      ),
  )
  AddDataformRepositoryResourceArg(dataform_source_group)
  dataform_source_group.add_argument(
      '--commit-sha',
      help=(
          'The commit SHA to read from the Dataform repository. If unset, the'
          ' file will be read from HEAD.'
      ),
  )
  gcs_source_group = notebook_source_group.add_group(
      help='The Cloud Storage notebook source.',
  )
  gcs_source_group.add_argument(
      '--gcs-notebook-uri',
      help=(
          'The Cloud Storage uri pointing to the notebook. Format: '
          'gs://bucket/notebook_file.ipynb'
      ),
      required=True,
  )
  gcs_source_group.add_argument(
      '--generation',
      help=(
          'The version of the Cloud Storage object to read. If unset, the'
          ' current version of the object will be used.'
      ),
  )
  notebook_source_group.add_argument(
      '--direct-content-from-file',
      help=(
          'The local filepath to an .ipynb file containing the notebook'
          ' content.'
      ),
  )
  execution_group.add_argument(
      '--execution-timeout',
      help=(
          "The max running time of the execution job, as a duration. See '$"
          " gcloud topic datetimes' for details on formatting the input"
          ' duration.'
      ),
      type=arg_parsers.Duration(),
      default='24h',
  )
  AddRuntimeTemplateResourceArg(execution_group)
  execution_group.add_argument(
      '--gcs-output-uri',
      help=(
          'The Cloud Storage location to upload notebook execution results to.'
          ' Format: gs://bucket-name.'
      ),
      required=True,
  )
  execution_identity_group = execution_group.add_group(
      help='Identity to run the execution as.',
      mutex=True,
      required=True,
  )
  execution_identity_group.add_argument(
      '--user-email',
      help=(
          'The user email to run the execution as. This requires the provided'
          ' runtime template to have end user credentials enabled.'
      ),
  )
  execution_identity_group.add_argument(
      '--service-account',
      help='The service account to run the execution as.',
      required=False,
  )
  AddKmsKeyResourceArg(
      execution_group,
      'The Cloud KMS encryption key (customer-managed encryption key) to'
      ' protect the execution. If the notebook runtime template already'
      ' specifies a customer-managed encryption key, that key will be used.'
      ' If unspecified in both, Google-managed encryption keys will be used.',
  )
  parser.add_argument(
      '--execution-job-id',
      help=(
          'The id to assign to the execution job. If not specified, a random id'
          ' will be generated.'
      ),
  )
  base.ASYNC_FLAG.AddToParser(parser)


def AddKmsKeyResourceArg(parser, help_text):
  """Adds Resource arg for KMS key to the parser.

  Args:
    parser: argparse parser for the command.
    help_text: str, the help text for the flag.
  """
  def GetKmsKeyResourceSpec():

    def KmsKeyAttributeConfig():
      # For anchor attribute, help text is generated automatically.
      return concepts.ResourceParameterAttributeConfig(name='kms-key')

    def KmsKeyringAttributeConfig():
      return concepts.ResourceParameterAttributeConfig(
          name='kms-keyring', help_text='KMS keyring id of the {resource}.'
      )

    def KmsLocationAttributeConfig():
      return concepts.ResourceParameterAttributeConfig(
          name='kms-location', help_text='Cloud location for the {resource}.'
      )

    def KmsProjectAttributeConfig():
      return concepts.ResourceParameterAttributeConfig(
          name='kms-project', help_text='Cloud project id for the {resource}.'
      )

    return concepts.ResourceSpec(
        'cloudkms.projects.locations.keyRings.cryptoKeys',
        resource_name='key',
        cryptoKeysId=KmsKeyAttributeConfig(),
        keyRingsId=KmsKeyringAttributeConfig(),
        locationsId=KmsLocationAttributeConfig(),
        projectsId=KmsProjectAttributeConfig(),
    )

  concept_parsers.ConceptParser.ForResource(
      '--kms-key',
      GetKmsKeyResourceSpec(),
      help_text,
      required=False,
  ).AddToParser(parser)


def AddDeleteExecutionFlags(parser):
  """Adds flags for deleting an execution to the parser."""
  AddExecutionResourceArg(parser, 'to delete')
  base.ASYNC_FLAG.AddToParser(parser)


def AddDescribeExecutionFlags(parser):
  """Adds flags for describing an execution to the parser."""
  AddExecutionResourceArg(parser, 'to describe')


def AddListRuntimeTemplatesFlags(parser):
  """Construct groups and arguments specific to listing runtime templates."""
  AddRegionResourceArg(parser, 'for which to list all executions')
  parser.display_info.AddUriFunc(executions_util.GetExecutionUri)