SPEC_OPTS=--colour --format nested

all: format_checking job_submit resources_creation
usage:
	@echo "usage: make < format_checking | job_submit | resources_creation >"
format_checking:
	rspec format_checking_spec.rb ${SPEC_OPTS}
job_submit:
	rspec job_submit_spec.rb ${SPEC_OPTS}
resources_creation:
	rspec resources_creation_spec.rb ${SPEC_OPTS}

