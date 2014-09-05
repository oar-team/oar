RSPEC=rspec
SPEC_OPTS=--colour --format nested

all: format_checking job_submit
usage:
	@echo "usage: make < format_checking | job_submit | resources_creation >"
format_checking:
	${RSPEC} format_checking_spec.rb ${SPEC_OPTS}
job_submit:
	${RSPEC} job_submit_spec.rb ${SPEC_OPTS}
resources_creation:
	${RSPEC} rspec resources_creation_spec.rb ${SPEC_OPTS}

